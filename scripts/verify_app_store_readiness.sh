#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
PROJECT_FILE="$PROJECT_PATH/project.pbxproj"
SCHEME="ClaraCoreMobile"
PRIVACY_POLICY_URL="https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/privacy-policy.md"
SUPPORT_URL="https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/support.md"
SUPPORT_CONTACT_URL="https://github.com/xiaomao361/claracore-mobile/issues"
RELEASE_DOC_DATE="2026-07-06"
PRIVACY_POLICY_EFFECTIVE_DATE="July 3, 2026"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-readiness.XXXXXX")"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT_DIR/.xcode-source-packages}"
PRESERVE_DERIVED_DATA=0

cleanup() {
  if [[ "$PRESERVE_DERIVED_DATA" == "1" ]]; then
    printf 'Readiness artifacts kept at: %s\n' "$DERIVED_DATA" >&2
  else
    rm -rf "$DERIVED_DATA"
  fi
}
trap cleanup EXIT

log() {
  printf '\n==> %s\n' "$1"
}

pass() {
  printf 'OK: %s\n' "$1"
}

fail() {
  PRESERVE_DERIVED_DATA=1
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

assert_http_200() {
  local url="$1"
  local status
  status="$(curl -L -s -o /dev/null -w '%{http_code}' "$url")"
  [[ "$status" == "200" ]] || fail "$url returned HTTP $status"
  pass "$url returned HTTP 200"
}

assert_plist_value() {
  local plist="$1"
  local key_path="$2"
  local expected="$3"
  local actual
  actual="$(/usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]] || fail "$plist $key_path expected '$expected' but got '${actual:-<missing>}'"
  pass "$plist $key_path = $expected"
}

assert_plist_key_absent() {
  local plist="$1"
  local key_path="$2"
  if /usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" >/dev/null 2>&1; then
    fail "$plist must not contain $key_path"
  fi
  pass "$plist does not contain $key_path"
}

assert_plist_array_count() {
  local plist="$1"
  local key_path="$2"
  local expected="$3"
  local actual
  actual="$(python3 - "$plist" "$key_path" <<'PY'
import plistlib
import sys
from pathlib import Path

plist = Path(sys.argv[1])
key_path = sys.argv[2].split(":")
with plist.open("rb") as handle:
    value = plistlib.load(handle)
for key in key_path:
    value = value[key]
if not isinstance(value, list):
    raise SystemExit("not-array")
print(len(value))
PY
)" || fail "$plist $key_path must be an array"
  [[ "$actual" == "$expected" ]] || fail "$plist $key_path expected $expected entries but got $actual"
  pass "$plist $key_path has $expected entries"
}

assert_privacy_manifest_declarations() {
  local manifest="$1"
  local label="$2"
  assert_plist_value "$manifest" "NSPrivacyTracking" "false"
  assert_plist_array_count "$manifest" "NSPrivacyTrackingDomains" "0"
  assert_plist_array_count "$manifest" "NSPrivacyCollectedDataTypes" "0"
  assert_plist_value "$manifest" "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType" "NSPrivacyAccessedAPICategoryUserDefaults"
  assert_plist_value "$manifest" "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0" "CA92.1"
  pass "$label PrivacyInfo declarations match App Store privacy claims"
}

assert_sips_property() {
  local image="$1"
  local property="$2"
  local expected="$3"
  local actual
  actual="$(sips -g "$property" "$image" 2>/dev/null | awk -F': ' -v key="$property" '$1 ~ key { print $2; exit }')"
  [[ "$actual" == "$expected" ]] || fail "$image $property expected '$expected' but got '${actual:-<missing>}'"
  pass "$image $property = $expected"
}

assert_pages_workflow_manual_only() {
  local workflow="$ROOT_DIR/.github/workflows/pages.yml"
  [[ -f "$workflow" ]] || {
    pass "GitHub Pages workflow is absent"
    return
  }
  rg -q '^[[:space:]]*workflow_dispatch:' "$workflow" || fail "Pages workflow must keep workflow_dispatch for manual deploys"
  if rg -q '^[[:space:]]*(push|pull_request):' "$workflow"; then
    fail "Pages workflow must not auto-run on push or pull_request while GitHub Pages is optional"
  fi
  pass "GitHub Pages workflow is manual-only"
}

assert_document_dates_current() {
  local files=(
    "$ROOT_DIR/docs/app-store/app-store-connect-metadata.md"
    "$ROOT_DIR/docs/app-store/app-store-submission.md"
    "$ROOT_DIR/docs/MANUAL_E2E_CHECKLIST.md"
  )

  local file
  for file in "${files[@]}"; do
    rg -q "^Date: $RELEASE_DOC_DATE$" "$file" || fail "$file must declare Date: $RELEASE_DOC_DATE"
    pass "$file declares Date: $RELEASE_DOC_DATE"
  done
  rg -q "^Effective date: $PRIVACY_POLICY_EFFECTIVE_DATE$" "$ROOT_DIR/docs/app-store/privacy-policy.md" || fail "Privacy policy must declare Effective date: $PRIVACY_POLICY_EFFECTIVE_DATE"
  pass "Privacy policy declares Effective date: $PRIVACY_POLICY_EFFECTIVE_DATE"
}

assert_in_app_privacy_copy() {
  local source="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  local public_privacy="$ROOT_DIR/docs/app-store/privacy-policy.md"
  local public_support="$ROOT_DIR/docs/app-store/support.md"
  rg -q '2026 年 7 月 3 日' "$source" || fail "Built-in privacy policy must show the July 3, 2026 effective date"
  rg -q 'iOS Keychain 的 ThisDeviceOnly 项中' "$source" || fail "Built-in privacy policy must disclose ThisDeviceOnly Keychain storage"
  rg -q 'Application Support 容器' "$source" || fail "Built-in privacy policy must disclose Application Support local storage"
  rg -q '不进入 iCloud 或 iTunes 备份' "$source" || fail "Built-in privacy policy must disclose local database backup exclusion"
  rg -q '未配置 Key 或未明确同意时，应用不会把导入内容发送给外部模型' "$source" || fail "Built-in privacy policy must disclose the local-first remote model boundary"
  rg -q '复制/分享完整原文 Archive' "$source" || fail "Built-in privacy policy must disclose complete Archive copy/share leaves the app by user action"
  rg -q 'Copying or sharing a complete original Archive entry' "$public_privacy" || fail "Public privacy policy must disclose complete Archive copy/share leaves the device by user action"
  rg -q 'copies/shares a complete original Archive entry' "$public_support" || fail "Public support page must disclose complete Archive copy/share leaves the device by user action"
  pass "Built-in privacy policy copy matches App Store privacy claims"
}

assert_database_backup_exclusion() {
  local database="$ROOT_DIR/ClaraCoreMobile/Core/Database/AppDatabase.swift"
  local tests="$ROOT_DIR/ClaraCoreMobileTests/Core/Database/AppDatabaseTests.swift"
  local project="$ROOT_DIR/ClaraCoreMobile.xcodeproj/project.pbxproj"
  local privacy="$ROOT_DIR/docs/app-store/privacy-policy.md"
  rg -q 'applicationSupportDirectory' "$database" || fail "App database must use Application Support storage"
  rg -q 'isExcludedFromBackup = true' "$database" || fail "App database must mark local data as excluded from backup"
  rg -q 'excludeFromBackup\(URL\(fileURLWithPath: databasePath\)\)' "$database" || fail "App database file must be excluded from backup"
  [[ -f "$tests" ]] || fail "App database backup exclusion tests are missing"
  rg -q 'testPreparedDatabaseDirectoryIsExcludedFromBackup' "$tests" || fail "App database tests must cover backup exclusion"
  rg -q 'Core/Database/AppDatabaseTests.swift in Sources' "$project" || fail "App database tests must be included in the XCTest target"
  rg -q "Application Support container" "$privacy" || fail "Public privacy policy must disclose Application Support local storage"
  rg -q "excluded from iCloud and iTunes backups" "$privacy" || fail "Public privacy policy must disclose local database backup exclusion"
  pass "Local database storage is Application Support backed and excluded from backup"
}

assert_local_data_clear_control() {
  local database="$ROOT_DIR/ClaraCoreMobile/Core/Database/AppDatabase.swift"
  local context_cards="$ROOT_DIR/ClaraCoreMobile/Core/ContextCard/ContextCardStore.swift"
  local settings_source="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  local api_key_source="$ROOT_DIR/ClaraCoreMobile/Core/Settings/APIKeyStore.swift"
  local tests="$ROOT_DIR/ClaraCoreMobileTests/Core/Database/AppDatabaseTests.swift"
  local shared_tests="$ROOT_DIR/ClaraCoreMobileTests/Shared/ClaraErrorPresenterTests.swift"
  local privacy="$ROOT_DIR/docs/app-store/privacy-policy.md"
  local support="$ROOT_DIR/docs/app-store/support.md"
  local checklist="$ROOT_DIR/docs/MANUAL_E2E_CHECKLIST.md"

  rg -q 'func deleteAllLocalUserData\(\) throws' "$database" || fail "App database must expose an all-local-user-data deletion transaction"
  rg -q 'DELETE FROM capture_segments' "$database" || fail "All-local-data deletion must clear capture segments"
  rg -q 'DELETE FROM import_sessions' "$database" || fail "All-local-data deletion must clear import sessions"
  rg -q 'DELETE FROM inbox' "$database" || fail "All-local-data deletion must clear Inbox"
  rg -q 'DELETE FROM memories' "$database" || fail "All-local-data deletion must clear memories"
  rg -q 'DELETE FROM continuity_lines' "$database" || fail "All-local-data deletion must clear Shared Lines"
  rg -q 'DELETE FROM context_cards' "$database" || fail "All-local-data deletion must clear Context Cards"
  rg -q 'func deleteAllLocalUserData\(\) throws' "$context_cards" || fail "ContextCardStore must expose a local-data deletion entry point for Settings"
  rg -q 'testDeleteAllLocalUserDataClearsUserTables' "$tests" || fail "App database tests must cover all-local-user-data deletion"

  rg -q 'Button\(role: \.destructive\)' "$settings_source" || fail "Settings local-data clear action must be destructive"
  rg -q 'Label\("清除本机数据", systemImage: "trash\.slash"\)' "$settings_source" || fail "Settings must expose a clear local data button"
  rg -q 'confirmationDialog\("清除本机数据？"' "$settings_source" || fail "Clear local data must require confirmation"
  rg -q 'Archive、Inbox、记忆、共同线、角色卡、模型配置和 Key' "$settings_source" || fail "Clear local data confirmation must describe its deletion scope"
  rg -q 'ModelProviderConfigurationStore\.reset\(\)' "$settings_source" || fail "Clear local data must reset model configuration"
  rg -q 'ExternalModelProcessingConsentStore\.reset\(\)' "$settings_source" || fail "Clear local data must reset external processing consent"
  rg -q 'apiKeyStore\.delete\(service: \.modelProvider\)' "$settings_source" || fail "Clear local data must delete the model provider key"
  rg -q 'apiKeyStore\.delete\(service: \.deepSeek\)' "$settings_source" || fail "Clear local data must delete the legacy DeepSeek key"
  rg -q 'contextCardStore\.defaultCard\(\)' "$settings_source" || fail "Clear local data must restore the default Context Card"
  rg -q 'static func reset\(userDefaults: UserDefaults = \.standard\)' "$api_key_source" || fail "Model and consent stores must expose reset helpers"
  rg -q 'externalModelProcessingConsentAccepted' "$api_key_source" || fail "External model consent must use external-model wording for the current UserDefaults key"
  rg -q 'legacyUserDefaultsKey = "thirdPartyAIProcessingConsentAccepted"' "$api_key_source" || fail "External model consent store must migrate the legacy third-party AI consent key"
  rg -q 'testExternalModelProcessingConsentMigratesLegacyAIKey' "$shared_tests" || fail "Tests must cover external model consent legacy key migration"
  rg -q 'testExternalModelProcessingConsentResetClearsCurrentAndLegacyKeys' "$shared_tests" || fail "Tests must cover clearing current and legacy external model consent keys"

  rg -q 'clear local app data from Settings' "$privacy" || fail "Public privacy policy must disclose the Settings clear-local-data control"
  rg -q 'How do I clear local data\?' "$support" || fail "Public support page must explain how to clear local data"
  rg -q 'Settings exposes a confirmed `清除本机数据` path' "$checklist" || fail "Manual E2E checklist must verify the Settings clear-local-data path"
  pass "Settings exposes a confirmed all-local-data clear path"
}

assert_in_app_support_copy() {
  local source="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  rg -q 'title: "版本信息"' "$source" || fail "Built-in support page must show version information"
  rg -q 'AppVersionInfo.displayText' "$source" || fail "Built-in support page must render the current app version/build"
  rg -q '复制诊断信息' "$source" || fail "Built-in support page must include a copy diagnostics action"
  rg -q 'UIPasteboard\.general\.string = AppVersionInfo\.supportDiagnosticText' "$source" || fail "Built-in support page must copy support diagnostics to the clipboard"
  rg -q 'organizationEngineStatus: organizationEngineStatus' "$source" || fail "Built-in support diagnostics must include the current organization engine status"
  rg -q '反馈时请附上诊断信息和问题发生前的操作' "$source" || fail "Built-in support page must ask users to include diagnostics and reproduction details"
  rg -q '不包含 API Key、导入原文、记忆、共同线、Provider 名称、Base URL、模型名称或模型配置' "$source" || fail "Built-in support page must disclose diagnostics exclude sensitive content and model provider details"
  rg -q 'provider names, Base URLs, model names, or model provider configuration' "$source" || fail "Copied support diagnostics must disclose model provider details are excluded"
  rg -q 'Organization engine preferred mode' "$source" || fail "Support diagnostics must include the non-sensitive preferred organization engine mode"
  rg -q 'External model activation complete' "$source" || fail "Support diagnostics must include non-sensitive external model activation state"
  rg -q 'External model missing requirements' "$source" || fail "Support diagnostics must include missing activation requirements without provider configuration"
  rg -q '打开 GitHub Issues' "$source" || fail "Built-in support page must expose the GitHub Issues support action"
  rg -q '使用清除本机数据' "$source" || fail "Built-in support page must explain the clear-local-data control"
  rg -q 'Archive、Inbox、记忆、共同线、角色卡、模型配置和 Key' "$source" || fail "Built-in support page must disclose the clear-local-data deletion scope"
  rg -q 'CFBundleShortVersionString' "$source" || fail "AppVersionInfo must read the marketing version"
  rg -q 'CFBundleVersion' "$source" || fail "AppVersionInfo must read the build number"
  rg -q 'CFBundleIdentifier' "$source" || fail "AppVersionInfo diagnostics must include the bundle identifier"
  pass "Built-in support copy includes version/build and support action"
}

assert_startup_failure_recovery() {
  local app_root="$ROOT_DIR/ClaraCoreMobile/App/AppRootView.swift"
  local database="$ROOT_DIR/ClaraCoreMobile/Core/Database/AppDatabase.swift"
  local tests="$ROOT_DIR/ClaraCoreMobileTests/Core/Database/AppDatabaseTests.swift"

  rg -q 'ContentUnavailableView\("启动失败"' "$app_root" || fail "Startup failure view must show a clear user-facing error state"
  rg -q 'Label\("重试启动", systemImage: "arrow\.clockwise"\)' "$app_root" || fail "Startup failure view must expose a retry action"
  rg -q 'confirmationDialog\("清除本机数据并重试启动？"' "$app_root" || fail "Startup local-data reset must require confirmation"
  rg -q 'Label\("清除本机数据并重试", systemImage: "trash\.slash"\)' "$app_root" || fail "Startup failure view must expose a local-data reset recovery action"
  rg -q 'AppDatabase\.deleteDefaultDatabaseDirectory\(\)' "$app_root" || fail "Startup reset recovery must clear the default database directory"
  rg -q 'ModelProviderConfigurationStore\.reset\(\)' "$app_root" || fail "Startup reset recovery must reset model configuration"
  rg -q 'ExternalModelProcessingConsentStore\.reset\(\)' "$app_root" || fail "Startup reset recovery must reset external processing consent"
  rg -q 'func deleteDefaultDatabaseDirectory\(\) throws' "$database" || fail "App database must expose a default storage reset helper"
  rg -q 'func deleteDatabaseDirectory\(_ directory: URL' "$database" || fail "App database must expose a testable storage-directory deletion helper"
  rg -q 'testDeleteDatabaseDirectoryRemovesLocalStorageDirectory' "$tests" || fail "App database tests must cover storage-directory deletion"
  pass "Startup failure view exposes retry and confirmed local-data reset recovery"
}

assert_keychain_accessibility() {
  local source="$ROOT_DIR/ClaraCoreMobile/Core/Settings/APIKeyStore.swift"
  local tests="$ROOT_DIR/ClaraCoreMobileTests/Shared/ClaraErrorPresenterTests.swift"
  rg -q 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' "$source" || fail "API keys must use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"
  rg -q 'enum StoreError: LocalizedError' "$source" || fail "Keychain store errors must be user-readable"
  rg -q '无法访问本机 Keychain' "$source" || fail "Keychain access failures must have a recovery-oriented message"
  rg -q '本机 Keychain 中的模型 Key 数据无法读取' "$source" || fail "Invalid Keychain data must have a recovery-oriented message"
  rg -q 'testPresentsKeychainAccessErrorsWithoutInternalStatusCodes' "$tests" || fail "Tests must cover user-visible Keychain access failures"
  rg -q 'testPresentsInvalidKeychainDataRecovery' "$tests" || fail "Tests must cover invalid Keychain data recovery"
  pass "API keys use ThisDeviceOnly Keychain storage with user-readable failure messages"
}

assert_model_provider_url_policy() {
  local settings="$ROOT_DIR/ClaraCoreMobile/Core/Settings/APIKeyStore.swift"
  local reflection="$ROOT_DIR/ClaraCoreMobile/Core/Reflection/DeepSeekReflectionService.swift"
  local deepseek_importer="$ROOT_DIR/ClaraCoreMobile/Core/Importer/DeepSeekShareImporter.swift"
  local conversation_importer="$ROOT_DIR/ClaraCoreMobile/Core/Importer/ConversationImporter.swift"
  local view="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  rg -q 'url\.scheme\?\.lowercased\(\) == "https"' "$settings" || fail "Model provider Base URL must require https"
  rg -q 'url\.host\?\.isEmpty == false' "$settings" || fail "Model provider Base URL must require a host"
  rg -q '必须使用完整 https:// 地址' "$view" || fail "Settings UI must explain the HTTPS Base URL requirement"
  pass "Model provider Base URL policy requires HTTPS with a host"

  rg -q 'static let requestTimeout: TimeInterval = 30' "$settings" || fail "Model provider listModels request must define a 30 second timeout"
  rg -q 'timeoutInterval: Self\.requestTimeout' "$settings" || fail "Model provider listModels request must use the timeout"
  rg -q 'static let requestTimeout: TimeInterval = 30' "$reflection" || fail "External model chat request must define a 30 second timeout"
  rg -q 'timeoutInterval: Self\.requestTimeout' "$reflection" || fail "External model chat request must use the timeout"
  rg -q 'static let requestTimeout: TimeInterval = 30' "$deepseek_importer" || fail "DeepSeek share import request must define a 30 second timeout"
  rg -q 'timeoutInterval: Self\.requestTimeout' "$deepseek_importer" || fail "DeepSeek share import request must use the timeout"
  rg -q 'static let requestTimeout: TimeInterval = 30' "$conversation_importer" || fail "Generic URL import request must define a 30 second timeout"
  rg -q 'URLRequest\(url: url, timeoutInterval: Self\.requestTimeout\)' "$conversation_importer" || fail "Generic URL import request must use the timeout"
  pass "External model and share-import network requests have bounded timeouts"
}

assert_local_rulebook_disclosure() {
  local rulebook="$ROOT_DIR/ClaraCoreMobile/Core/Reflection/LocalOrganizationRulebook.swift"
  local local_service="$ROOT_DIR/ClaraCoreMobile/Core/Reflection/RuleBasedReflectionService.swift"
  local settings_source="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  local importer_source="$ROOT_DIR/ClaraCoreMobile/Features/Importer/ImporterFeatureView.swift"
  local configuration="$ROOT_DIR/ClaraCoreMobile/Core/Settings/APIKeyStore.swift"
  local inbox="$ROOT_DIR/ClaraCoreMobile/Features/Inbox/InboxFeatureView.swift"
  local tests="$ROOT_DIR/ClaraCoreMobileTests/Shared/ClaraErrorPresenterTests.swift"
  [[ -f "$rulebook" ]] || fail "Local organization rulebook source is missing"
  rg -q 'version = "local-v1"' "$rulebook" || fail "Local organization rulebook must declare a stable user-visible version"
  rg -q 'settingsSummary' "$rulebook" || fail "Local organization rulebook must expose a Settings summary"
  rg -q '不会把导入内容发送给模型提供方' "$rulebook" || fail "Local organization rulebook must disclose local privacy boundary"
  rg -q 'private let rulebook: LocalOrganizationRulebook' "$local_service" || fail "Rule-based reflection must store the shared local rulebook"
  rg -q 'init\(rulebook: LocalOrganizationRulebook = \.current\)' "$local_service" || fail "Rule-based reflection must default to the current local rulebook"
  rg -q 'LocalOrganizationRulebook\.current\.settingsSummary' "$settings_source" || fail "Settings UI must display the local rulebook summary"
  rg -q 'var organizingStatusTitle' "$configuration" || fail "Reflection configuration must expose a runtime-specific organizing status title"
  rg -q 'var segmentProgressPrivacyDetail' "$configuration" || fail "Reflection configuration must expose per-mode privacy progress detail"
  rg -q 'reflectionConfiguration\.mode\.organizingStatusTitle' "$inbox" || fail "Inbox organizing pill must name the actual runtime mechanism"
  rg -q 'reflectionConfiguration\.mode\.organizingTitle' "$inbox" || fail "Inbox progress title must name the actual runtime mechanism"
  rg -q 'reflectionConfiguration\.mode\.segmentProgressPrivacyDetail' "$inbox" || fail "Inbox segment progress must disclose the active privacy boundary"
  rg -q 'testReflectionConfigurationModeLabelsDiscloseActualRuntimeMechanism' "$tests" || fail "Tests must cover runtime-specific organization labels"
  rg -q 'testLiveDependenciesKeepLocalRulesWhenExternalModelIsOnlySelected' "$tests" || fail "Tests must prove selecting external model alone keeps local-rule dependencies"
  rg -q 'testLiveDependenciesEnableRemoteModelOnlyAfterAllActivationConditionsAreMet' "$tests" || fail "Tests must prove remote dependencies require every external-model activation condition"
  rg -q 'testExternalModelStatusDoesNotTreatUnsavedDraftConfigurationAsEffective' "$tests" || fail "Tests must prove unsaved model configuration drafts do not count as the effective engine configuration"
  rg -q 'savedModelConfiguration' "$settings_source" || fail "Settings UI must calculate engine status from the saved model configuration, not the edit draft"
  rg -q 'unsavedConfigurationSummary' "$settings_source" || fail "Settings UI must warn when model configuration edits are not saved yet"
  rg -q 'onShowSettings' "$importer_source" || fail "Importer engine status must provide a direct Settings path"
  rg -q 'shouldShowImportSettingsAction' "$importer_source" || fail "Importer engine status must show a Settings action when the external model is not active"
  rg -q 'importSettingsActionTitle' "$importer_source" || fail "Importer engine status action must explain whether users should switch mode or complete activation"
  rg -q 'accessibilityIdentifier\("import-engine-settings-action"\)' "$importer_source" || fail "Importer engine Settings action must have a stable accessibility identifier"
  rg -q 'direct Settings path from `本次整理机制`' "$ROOT_DIR/docs/MANUAL_E2E_CHECKLIST.md" || fail "Manual E2E checklist must verify the Import engine Settings path"
  rg -q 'XCTAssertEqual\(status\.importSettingsActionTitle, "切换整理方式"\)' "$tests" || fail "Tests must cover the local-rule importer Settings action title"
  rg -q 'XCTAssertEqual\(status\.importSettingsActionTitle, "补全启用条件"\)' "$tests" || fail "Tests must cover the incomplete external-model importer Settings action title"
  pass "Local organization rulebook is user-visible and shared by the local reflection engine"
}

assert_destructive_delete_confirmations() {
  local archive="$ROOT_DIR/ClaraCoreMobile/Features/Archive/ArchiveFeatureView.swift"
  local inbox="$ROOT_DIR/ClaraCoreMobile/Features/Inbox/InboxFeatureView.swift"
  local memoria="$ROOT_DIR/ClaraCoreMobile/Features/Memoria/MemoriaFeatureView.swift"
  local continuity="$ROOT_DIR/ClaraCoreMobile/Features/Continuity/ContinuityFeatureView.swift"
  local settings="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  rg -q 'confirmationDialog\("删除原文 Archive？"' "$archive" || fail "Archive deletion must require confirmation"
  rg -q 'confirmationDialog\("丢弃待处理导入？"' "$inbox" || fail "Inbox discard must require confirmation"
  rg -q '已经提交的记忆、共同线和原文 Archive 不会被删除' "$inbox" || fail "Inbox discard confirmation must explain committed data is preserved"
  rg -q 'confirmationDialog\("删除记忆？"' "$memoria" || fail "Memory deletion must require confirmation"
  rg -q '原始对话 Archive 和共同线不会被同时删除' "$memoria" || fail "Memory deletion confirmation must explain its boundary"
  rg -q 'confirmationDialog\("删除共同线？"' "$continuity" || fail "Shared Line deletion must require confirmation"
  rg -q '记忆本身不会被同时删除' "$continuity" || fail "Shared Line deletion confirmation must explain its boundary"
  rg -q 'confirmationDialog\("删除模型 Key？"' "$settings" || fail "Model API key deletion must require confirmation"
  rg -q '已导入的 Archive、记忆和共同线不会被删除' "$settings" || fail "Model API key deletion confirmation must explain stored content is preserved"
  pass "Destructive Archive, Inbox, Memory, Shared Line, and model key actions require confirmation"
}

assert_recall_copy_boundary() {
  local view="$ROOT_DIR/ClaraCoreMobile/Features/Recall/RecallPackageView.swift"
  local package="$ROOT_DIR/ClaraCoreMobile/Core/Recall/RecallContextPackage.swift"
  local tests="$ROOT_DIR/ClaraCoreMobileTests/Core/Recall/RecallContextPackageTests.swift"
  local checklist="$ROOT_DIR/docs/MANUAL_E2E_CHECKLIST.md"

  rg -q 'UIPasteboard\.general\.string = package\.formattedText' "$view" || fail "Recall copy must use the formatted recall package"
  rg -q '不会复制 API Key、Base URL、模型配置或完整原文 Archive' "$view" || fail "Recall copy UI must disclose excluded sensitive/configuration content"
  rg -q 'contextCard\.agentProfile' "$package" || fail "Recall package must include the Context Card agent profile"
  rg -q 'contextCard\.userProfile' "$package" || fail "Recall package must include the Context Card user profile"
  rg -q 'line\.richRecallText' "$package" || fail "Recall package must include rich Shared Line continuity state"
  rg -q 'request\.normalizedRecallRequest' "$package" || fail "Recall package must normalize blank continuation requests before copying"
  rg -q 'testFormattedTextExcludesModelProviderConfigurationAndRawArchiveByDefault' "$tests" || fail "Recall package tests must cover sensitive/configuration exclusions"
  rg -q 'testBlankRecallRequestFallsBackToDefaultContinuationInstruction' "$tests" || fail "Recall package tests must cover blank request fallback"
  rg -q 'testRecallRequestIsTrimmedBeforeCopying' "$tests" || fail "Recall package tests must cover trimming copied continuation requests"
  rg -q 'Confirm the screen explains it will not copy API Key, Base URL, model configuration, or the complete raw Archive\.' "$checklist" || fail "Manual E2E checklist must verify recall copy boundary disclosure"
  rg -q 'Clear the `接下来怎么继续` text, copy again, and confirm the package falls back to the default continuation instruction' "$checklist" || fail "Manual E2E checklist must verify blank recall request fallback"
  rg -q 'A blank recall continuation request falls back to the default continuation instruction before copying\.' "$checklist" || fail "Manual E2E pass criteria must cover blank recall request fallback"
  pass "Recall package copy path discloses and tests sensitive/configuration exclusions"
}

assert_archive_copy_boundary() {
  local archive="$ROOT_DIR/ClaraCoreMobile/Features/Archive/ArchiveFeatureView.swift"
  local checklist="$ROOT_DIR/docs/MANUAL_E2E_CHECKLIST.md"

  rg -q 'UIPasteboard\.general\.string = item\.rawContent' "$archive" || fail "Archive raw copy must copy the selected archive raw content"
  rg -q '完整原文已复制到系统剪贴板' "$archive" || fail "Archive raw copy status must disclose the complete raw text was copied"
  rg -q '完整原文交给系统剪贴板或分享面板' "$archive" || fail "Archive raw copy/share UI must disclose clipboard and share sheet privacy boundary"
  rg -q 'Confirm copying or sharing Archive raw text explains it places the complete original text on the system clipboard or share sheet\.' "$checklist" || fail "Manual E2E checklist must verify Archive raw copy/share disclosure"
  pass "Archive raw copy/share path discloses complete-original clipboard and share-sheet boundary"
}

assert_import_size_guard() {
  local raw_capture="$ROOT_DIR/ClaraCoreMobile/Core/Importer/RawCapture.swift"
  local importer_view="$ROOT_DIR/ClaraCoreMobile/Features/Importer/ImporterFeatureView.swift"
  local preparer="$ROOT_DIR/ClaraCoreMobile/Core/Importer/ImportSessionPreparer.swift"
  local preparer_tests="$ROOT_DIR/ClaraCoreMobileTests/Core/Importer/ImportSessionPreparerTests.swift"
  local presenter_tests="$ROOT_DIR/ClaraCoreMobileTests/Shared/ClaraErrorPresenterTests.swift"

  rg -q 'static let maxImportCharacters = 240_000' "$raw_capture" || fail "RawCapture must define the first-release import size limit"
  rg -q 'case emptyImport' "$raw_capture" || fail "RawCapture must expose a user-visible empty import error"
  rg -q 'case oversizedImport' "$raw_capture" || fail "RawCapture must expose a user-visible oversized import error"
  rg -q 'func validateForImport' "$raw_capture" || fail "RawCapture must expose a reusable import validation helper"
  rg -q 'rawContent\.trimmingCharacters\(in: \.whitespacesAndNewlines\)\.isEmpty' "$raw_capture" || fail "RawCapture validation must reject blank imported content"
  rg -q 'try capture\.validateForImport\(\)' "$importer_view" || fail "Importer screen must validate capture size before enqueueing"
  rg -q 'try capture\.validateForImport\(\)' "$preparer" || fail "ImportSessionPreparer must validate capture size before creating sessions"
  rg -q 'testPrepareRejectsBlankImportBeforeCreatingSession' "$preparer_tests" || fail "ImportSessionPreparer tests must cover blank import rejection"
  rg -q 'testPrepareRejectsOversizedImportBeforeCreatingSession' "$preparer_tests" || fail "ImportSessionPreparer tests must cover oversized import rejection"
  rg -q 'testPresentsEmptyRawCaptureImportError' "$presenter_tests" || fail "ClaraErrorPresenter tests must cover the empty import message"
  rg -q 'testPresentsOversizedImportError' "$presenter_tests" || fail "ClaraErrorPresenter tests must cover the oversized import message"
  pass "Blank and oversized imports are rejected with user-visible messages before session creation"
}

assert_url_import_https_guard() {
  local importer="$ROOT_DIR/ClaraCoreMobile/Core/Importer/ConversationImporter.swift"
  local importer_tests="$ROOT_DIR/ClaraCoreMobileTests/Core/Importer/ConversationImporterRegistryTests.swift"
  local presenter_tests="$ROOT_DIR/ClaraCoreMobileTests/Shared/ClaraErrorPresenterTests.swift"
  local project="$ROOT_DIR/ClaraCoreMobile.xcodeproj/project.pbxproj"

  rg -q 'case insecureURL' "$importer" || fail "URL importer must expose an insecure URL error"
  rg -q 'url\.scheme\?\.lowercased\(\) != "https"' "$importer" || fail "URL importer must reject non-HTTPS URL imports"
  rg -q '链接导入只支持 https:// 公开链接' "$importer" || fail "URL importer must provide an actionable HTTPS-only error"
  rg -q 'testRegistryRejectsInsecureURLBeforeNetworkImport' "$importer_tests" || fail "Importer tests must prove insecure URLs are rejected before network loading"
  rg -q 'testPresentsInsecureURLImportError' "$presenter_tests" || fail "Error presenter tests must cover insecure URL import errors"
  if rg -q 'NSAllowsArbitraryLoads|NSAppTransportSecurity' "$project"; then
    fail "Project must not loosen App Transport Security for URL import"
  fi
  pass "URL imports require HTTPS and do not loosen App Transport Security"
}

assert_reflection_runner_segment_guard() {
  local runner="$ROOT_DIR/ClaraCoreMobile/Core/Reflection/ReflectionRunner.swift"
  local runner_tests="$ROOT_DIR/ClaraCoreMobileTests/Core/Reflection/ReflectionRunnerTests.swift"
  local presenter_tests="$ROOT_DIR/ClaraCoreMobileTests/Shared/ClaraErrorPresenterTests.swift"

  rg -q 'enum RunnerError: LocalizedError' "$runner" || fail "ReflectionRunner must expose user-visible runner errors"
  rg -q 'case noSegments' "$runner" || fail "ReflectionRunner must reject empty prepared sessions"
  rg -q 'guard !prepared\.segments\.isEmpty else' "$runner" || fail "ReflectionRunner must guard against zero segments before reflection"
  rg -q '没有可整理的内容片段' "$runner" || fail "ReflectionRunner no-segments error must be user-readable"
  rg -q 'testRunRejectsEmptyPreparedSessionBeforeReflection' "$runner_tests" || fail "ReflectionRunner tests must cover empty prepared sessions"
  rg -q 'testPresentsNoSegmentsReflectionRunnerError' "$presenter_tests" || fail "ClaraErrorPresenter tests must cover no-segments runner errors"
  pass "Reflection runner rejects zero-segment prepared sessions before reflection"
}

assert_user_visible_errors_are_presented_safely() {
  local presenter="$ROOT_DIR/ClaraCoreMobile/Shared/ClaraErrorPresenter.swift"
  local settings="$ROOT_DIR/ClaraCoreMobile/Core/Settings/APIKeyStore.swift"
  local reflection="$ROOT_DIR/ClaraCoreMobile/Core/Reflection/DeepSeekReflectionService.swift"
  local tests="$ROOT_DIR/ClaraCoreMobileTests/Shared/ClaraErrorPresenterTests.swift"
  local findings
  findings="$(
    rg -n 'error\.localizedDescription' "$ROOT_DIR/ClaraCoreMobile" -g '*.swift' \
      | rg -v 'ClaraCoreMobile/Shared/ClaraErrorPresenter.swift|ClaraCoreMobile/Core/Reflection/DeepSeekReflectionService.swift' || true
  )"
  [[ -z "$findings" ]] || fail "User-visible feature errors must use ClaraErrorPresenter instead of raw localizedDescription: $findings"
  rg -q 'enum UserVisibleErrorDetailSanitizer' "$presenter" || fail "User-visible provider error details must have a sanitizer"
  rg -q 'providerResponseDetail\(from: body\)' "$settings" || fail "Model list HTTP errors must sanitize provider response bodies"
  rg -q 'providerResponseDetail\(from: body\)' "$reflection" || fail "External model HTTP errors must sanitize provider response bodies"
  rg -q 'testProviderHTTPErrorDetailsAreRedactedAndBounded' "$tests" || fail "Tests must cover redacted and bounded provider HTTP error details"
  rg -q 'testProviderHTTPErrorUsesGenericMessageWhenBodyIsBlank' "$tests" || fail "Tests must cover blank provider HTTP error bodies"
  pass "User-visible feature errors use ClaraErrorPresenter"
}

assert_scene_manifest_not_generated() {
  if rg -q 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;' "$PROJECT_FILE"; then
    fail "SwiftUI app must not generate an empty UIApplicationSceneManifest; it fails simulator launch preflight"
  fi
  pass "SwiftUI scene manifest generation is disabled"
}

assert_in_app_public_urls() {
  local source="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  rg -q "privacyPolicy = URL\\(string: \"$PRIVACY_POLICY_URL\"\\)" "$source" || fail "In-app privacy policy URL must match $PRIVACY_POLICY_URL"
  rg -q "support = URL\\(string: \"$SUPPORT_URL\"\\)" "$source" || fail "In-app support URL must match $SUPPORT_URL"
  rg -q "URL\\(string: \"$SUPPORT_CONTACT_URL\"\\)" "$source" || fail "In-app support contact URL must match $SUPPORT_CONTACT_URL"
  pass "In-app public URLs match readiness source of truth"
}

assert_screenshot_plan() {
  local plan="$ROOT_DIR/docs/app-store/screenshot-plan.md"
  local capture="$ROOT_DIR/scripts/capture_app_store_screenshots.sh"
  local verifier="$ROOT_DIR/scripts/verify_app_store_screenshots.sh"
  local submission="$ROOT_DIR/docs/app-store/app-store-submission.md"
  local screenshot_seed="$ROOT_DIR/ClaraCoreMobile/App/AppStoreScreenshotFixtureSeeder.swift"
  local settings_view="$ROOT_DIR/ClaraCoreMobile/Features/Settings/SettingsFeatureView.swift"
  [[ -f "$plan" ]] || fail "Screenshot plan is missing at $plan"
  [[ -x "$capture" ]] || fail "Screenshot capture script must exist and be executable at $capture"
  [[ -x "$verifier" ]] || fail "Screenshot verifier must exist and be executable at $verifier"
  [[ -f "$screenshot_seed" ]] || fail "Screenshot fixture seeder must exist at $screenshot_seed"
  rg -q 'CONFIGURATION="\$\{CONFIGURATION:-Release\}"' "$capture" || fail "Screenshot capture must default to Release builds"
  rg -q 'CONFIGURATION[[:space:]]+Xcode build configuration\. Default: Release' "$capture" || fail "Screenshot capture help must document the Release default"
  rg -q 'CLARACORE_SCREENSHOT_MODE' "$capture" || fail "Screenshot capture must launch the app in screenshot fixture mode"
  rg -q 'CLARACORE_SCREENSHOT_TAB' "$capture" || fail "Screenshot capture must target individual app tabs"
  rg -q 'CLARACORE_SCREENSHOT_MODE' "$plan" || fail "Screenshot plan must document screenshot fixture mode"
  rg -q 'AUTO_CAPTURED_SCREENSHOTS=01-import,02-settings-model,03-import-result,04-archive,05-memory,06-shared-line,07-recall-package,08-settings-support' "$plan" || fail "Screenshot plan must document the full auto-captured screen sequence"
  rg -q 'AUTO_CAPTURED_SCREENSHOTS=01-import,02-settings-model,03-import-result,04-archive,05-memory,06-shared-line,07-recall-package,08-settings-support' "$capture" || fail "Screenshot capture manifest must record the full auto-captured screen sequence"
  rg -q 'AppStoreScreenshotFixtureSeeder\.swift' "$PROJECT_FILE" || fail "Screenshot fixture seeder must be included in the app target project"
  rg -q 'tabEnvironmentKey = "CLARACORE_SCREENSHOT_TAB"' "$screenshot_seed" || fail "Screenshot fixture seeder must support tab-targeted launch"
  rg -q 'sampleModelConfiguration' "$screenshot_seed" || fail "Screenshot fixture seeder must seed a safe model configuration for Settings screenshots"
  rg -q 'case importResult = "import-result"' "$screenshot_seed" || fail "Screenshot fixture seeder must support the import-result screenshot target"
  rg -q 'case recallPackage = "recall-package"' "$screenshot_seed" || fail "Screenshot fixture seeder must support the recall-package screenshot target"
  rg -q 'case settingsSupport = "settings-support"' "$screenshot_seed" || fail "Screenshot fixture seeder must support the settings-support screenshot target"
  rg -q 'app-store-screenshot-sample-import' "$screenshot_seed" || fail "Screenshot fixture seeder must use a deterministic sample import id"
  rg -q 'screenshot-sample' "$screenshot_seed" || fail "Screenshot fixture seeder must mark sample memories"
  rg -q 'sampleCommitResult' "$screenshot_seed" || fail "Screenshot fixture seeder must provide a safe import result for screenshots"
  rg -q 'recallPackage' "$ROOT_DIR/ClaraCoreMobile/App/AppRootView.swift" || fail "App root must support direct recall package screenshots"
  rg -q 'isAppStoreScreenshotMode' "$settings_view" || fail "Settings UI must expose the model configuration first in screenshot mode"
  rg -q 'settingsSupport' "$settings_view" || fail "Settings UI must expose support/privacy first for settings-support screenshots"
  rg -q 'testScreenshotFixtureSeederMapsRequestedInitialTabs' "$ROOT_DIR/ClaraCoreMobileTests/Core/Database/AppDatabaseTests.swift" || fail "Tests must cover screenshot fixture tab routing"
  rg -q 'testScreenshotFixtureSeederKeepsImportTargetCleanForFirstScreenshot' "$ROOT_DIR/ClaraCoreMobileTests/Core/Database/AppDatabaseTests.swift" || fail "Tests must cover the clean import screenshot fixture"
  rg -q "^Date: $RELEASE_DOC_DATE$" "$plan" || fail "Screenshot plan must declare Date: $RELEASE_DOC_DATE"
  rg -q 'scripts/capture_app_store_screenshots\.sh' "$plan" || fail "Screenshot plan must tell the submitter how to capture screenshots"
  rg -q 'scripts/capture_app_store_screenshots\.sh' "$submission" || fail "Submission checklist must include the screenshot capture script"
  rg -q 'scripts/verify_app_store_screenshots\.sh' "$plan" || fail "Screenshot plan must tell the submitter to run the screenshot verifier"
  rg -q 'manifest\.txt' "$plan" || fail "Screenshot plan must document the screenshot manifest"
  rg -q 'manifest\.txt' "$capture" || fail "Screenshot capture must write a manifest"
  rg -q 'SCREENSHOT_SEQUENCE' "$plan" || fail "Screenshot plan must document the final screenshot manifest sequence"
  rg -q 'SCREENSHOT_SEQUENCE' "$capture" || fail "Screenshot capture manifest must record the final screenshot sequence"
  rg -q 'MARKETING_VERSION' "$capture" || fail "Screenshot capture manifest must record MARKETING_VERSION"
  rg -q 'CURRENT_PROJECT_VERSION' "$capture" || fail "Screenshot capture manifest must record CURRENT_PROJECT_VERSION"
  rg -q 'run_xcodebuild_with_timeout\.sh' "$capture" || fail "Screenshot capture must run xcodebuild with a timeout"
  rg -q -- '-clonedSourcePackagesDirPath "\$SOURCE_PACKAGES_DIR"' "$capture" || fail "Screenshot capture must reuse the SwiftPM package cache"
  rg -q 'assert_manifest' "$verifier" || fail "Screenshot verifier must validate the manifest"
  rg -q 'assert_screenshot_content' "$verifier" || fail "Screenshot verifier must reject blank or single-color captures"
  rg -q 'assert_no_duplicate_screenshot_content' "$verifier" || fail "Screenshot verifier must reject duplicate final screenshot content"
  rg -q 'image_content_signature' "$verifier" || fail "Screenshot verifier must compare screenshot pixel signatures"
  rg -q 'MIN_SCREENSHOTS_PER_DEVICE' "$verifier" || fail "Screenshot verifier must support final-package minimum screenshot counts"
  rg -q 'assert_final_screenshot_sequence' "$verifier" || fail "Screenshot verifier must require the final first-release screenshot sequence"
  rg -q 'SCREENSHOT_SEQUENCE' "$verifier" || fail "Screenshot verifier must validate the final screenshot manifest sequence"
  rg -q 'CONFIGURATION must be Release' "$verifier" || fail "Screenshot verifier must require Release screenshot captures"
  rg -q 'docs/app-store/screenshots/' "$plan" || fail "Screenshot plan must define the local screenshot directory"
  rg -q 'copy or share one complete original Archive entry' "$submission" || fail "Submission App Review notes must include Archive original copy/share review path"
  rg -q 'TARGETED_DEVICE_FAMILY = "1,2";' "$PROJECT_FILE" || fail "Unexpected TARGETED_DEVICE_FAMILY; review screenshot plan requirements"
  rg -q 'iPhone 6\.9-inch' "$plan" || fail "Screenshot plan must include iPhone 6.9-inch screenshots"
  rg -q 'iPad 13-inch' "$plan" || fail "Screenshot plan must include iPad 13-inch screenshots"
  rg -q '1320 x 2868' "$plan" || fail "Screenshot plan must include an accepted iPhone 6.9-inch portrait size"
  rg -q '2064 x 2752' "$plan" || fail "Screenshot plan must include an accepted iPad 13-inch portrait size"
  rg -q 'duplicate' "$plan" || fail "Screenshot plan must tell submitters duplicate screenshots are rejected"
  rg -q '`01-import`: Import screen with role card selector, source input, paste/file actions, `本次整理机制`, and the direct Settings action' "$plan" || fail "Screenshot plan must require the import screen to show the active organization mechanism and Settings action"
  for screenshot_name in \
    '01-import' \
    '02-settings-model' \
    '03-import-result' \
    '04-archive' \
    '05-memory' \
    '06-shared-line' \
    '07-recall-package' \
    '08-settings-support'; do
    rg -q "$screenshot_name" "$plan" || fail "Screenshot plan must document $screenshot_name"
    rg -q "$screenshot_name" "$verifier" || fail "Screenshot verifier must require $screenshot_name in final mode"
  done
  pass "Screenshot plan covers iPhone and iPad App Store requirements"

  "$verifier" "$ROOT_DIR/docs/app-store/screenshots" >/dev/null
  pass "Screenshot files are present and match App Store device-size requirements"
}

assert_simulator_smoke_check_documented() {
  local smoke="$ROOT_DIR/scripts/smoke_simulator_launch.sh"
  local unit_tests="$ROOT_DIR/scripts/verify_unit_tests.sh"
  local device_release="$ROOT_DIR/scripts/verify_device_release_build.sh"
  local archive="$ROOT_DIR/scripts/verify_app_store_archive.sh"
  local signing="$ROOT_DIR/scripts/verify_app_store_signing_prerequisites.sh"
  local signed_artifacts="$ROOT_DIR/scripts/verify_signed_app_store_artifacts.sh"
  local export_signed="$ROOT_DIR/scripts/export_signed_app_store_archive.sh"
  local export_options="$ROOT_DIR/docs/app-store/export-options-app-store-connect.plist"
  local submission_ready="$ROOT_DIR/scripts/verify_app_store_submission_ready.sh"
  local public_docs="$ROOT_DIR/scripts/verify_public_app_store_docs.sh"
  local tracked_artifacts="$ROOT_DIR/scripts/verify_release_artifacts_tracked.sh"
  local clean_worktree="$ROOT_DIR/scripts/verify_release_worktree_clean.sh"
  local xcodebuild_timeout="$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh"
  local submission="$ROOT_DIR/docs/app-store/app-store-submission.md"
  local checklist="$ROOT_DIR/docs/MANUAL_E2E_CHECKLIST.md"
  rg -q '^\.xcode-source-packages/$' "$ROOT_DIR/.gitignore" || fail ".gitignore must exclude the reused SwiftPM package cache"
  [[ -x "$smoke" ]] || fail "Simulator launch smoke script must exist and be executable at $smoke"
  [[ -x "$unit_tests" ]] || fail "Unit test verifier must exist and be executable at $unit_tests"
  [[ -x "$device_release" ]] || fail "Device Release build verifier must exist and be executable at $device_release"
  [[ -x "$archive" ]] || fail "App Store archive verifier must exist and be executable at $archive"
  [[ -x "$signing" ]] || fail "App Store signing prerequisite verifier must exist and be executable at $signing"
  [[ -x "$signed_artifacts" ]] || fail "Signed App Store artifact verifier must exist and be executable at $signed_artifacts"
  [[ -x "$export_signed" ]] || fail "Signed App Store export script must exist and be executable at $export_signed"
  [[ -f "$export_options" ]] || fail "App Store Connect export options plist must exist at $export_options"
  [[ -x "$submission_ready" ]] || fail "Final App Store submission verifier must exist and be executable at $submission_ready"
  [[ -x "$public_docs" ]] || fail "Public App Store docs verifier must exist and be executable at $public_docs"
  [[ -x "$tracked_artifacts" ]] || fail "Release tracked-artifacts verifier must exist and be executable at $tracked_artifacts"
  [[ -x "$clean_worktree" ]] || fail "Release clean-worktree verifier must exist and be executable at $clean_worktree"
  [[ -x "$xcodebuild_timeout" ]] || fail "xcodebuild timeout runner must exist and be executable at $xcodebuild_timeout"
  rg -q 'git -C "\$ROOT_DIR" ls-files --error-unmatch' "$tracked_artifacts" || fail "Tracked-artifacts verifier must use Git index checks without mutating Git"
  rg -q 'This script did not modify Git' "$tracked_artifacts" || fail "Tracked-artifacts verifier must state that it does not mutate Git"
  rg -q 'ClaraCoreMobile/App/AppStoreScreenshotFixtureSeeder\.swift' "$tracked_artifacts" || fail "Tracked-artifacts verifier must require the screenshot fixture seeder"
  rg -q 'docs/app-store/screenshots/manifest\.txt' "$tracked_artifacts" || fail "Tracked-artifacts verifier must require the screenshot manifest"
  rg -q 'docs/app-store/screenshots/iphone-6\.9/01-import\.png' "$tracked_artifacts" || fail "Tracked-artifacts verifier must require final iPhone screenshots"
  rg -q 'docs/app-store/screenshots/ipad-13/01-import\.png' "$tracked_artifacts" || fail "Tracked-artifacts verifier must require final iPad screenshots"
  rg -q 'scripts/verify_release_artifacts_tracked\.sh' "$tracked_artifacts" || fail "Tracked-artifacts verifier must require itself"
  rg -q 'scripts/verify_release_worktree_clean\.sh' "$tracked_artifacts" || fail "Tracked-artifacts verifier must require the clean-worktree gate"
  rg -q 'git -C "\$ROOT_DIR" status --porcelain' "$clean_worktree" || fail "Clean-worktree verifier must inspect Git status without mutating Git"
  rg -q 'This script did not modify Git' "$clean_worktree" || fail "Clean-worktree verifier must state that it does not mutate Git"
  rg -q 'start_new_session=True' "$xcodebuild_timeout" || fail "xcodebuild timeout runner must isolate xcodebuild in its own process group"
  rg -q 'killpg' "$xcodebuild_timeout" || fail "xcodebuild timeout runner must terminate timed-out process groups"
  rg -q 'PRESERVE_DERIVED_DATA=1' "$unit_tests" || fail "Unit test verifier must preserve artifacts on failure"
  rg -q 'XCTest artifacts kept at:' "$unit_tests" || fail "Unit test verifier must print preserved artifact path on failure"
  rg -q 'run_xcodebuild_with_timeout\.sh' "$unit_tests" || fail "Unit test verifier must run xcodebuild with a timeout"
  rg -q -- '-clonedSourcePackagesDirPath "\$SOURCE_PACKAGES_DIR"' "$unit_tests" || fail "Unit test verifier must reuse the SwiftPM package cache"
  rg -q 'PRESERVE_DERIVED_DATA=1' "$smoke" || fail "Simulator smoke verifier must preserve artifacts on failure"
  rg -q 'Simulator smoke artifacts kept at:' "$smoke" || fail "Simulator smoke verifier must print preserved artifact path on failure"
  rg -q 'run_xcodebuild_with_timeout\.sh' "$smoke" || fail "Simulator smoke verifier must run xcodebuild with a timeout"
  rg -q -- '-clonedSourcePackagesDirPath "\$SOURCE_PACKAGES_DIR"' "$smoke" || fail "Simulator smoke verifier must reuse the SwiftPM package cache"
  rg -q 'PRESERVE_DERIVED_DATA=1' "$device_release" || fail "Device Release verifier must preserve artifacts on failure"
  rg -q 'Device Release build artifacts kept at:' "$device_release" || fail "Device Release verifier must print preserved artifact path on failure"
  rg -q 'run_xcodebuild_with_timeout\.sh' "$device_release" || fail "Device Release verifier must run xcodebuild with a timeout"
  rg -q -- '-clonedSourcePackagesDirPath "\$SOURCE_PACKAGES_DIR"' "$device_release" || fail "Device Release verifier must reuse the SwiftPM package cache"
  rg -q 'PRESERVE_ARCHIVE_ROOT=1' "$archive" || fail "Archive verifier must preserve artifacts on failure"
  rg -q 'Archive artifacts kept at:' "$archive" || fail "Archive verifier must print preserved artifact path on failure"
  rg -q 'run_xcodebuild_with_timeout\.sh' "$archive" || fail "Archive verifier must run xcodebuild with a timeout"
  rg -q -- '-clonedSourcePackagesDirPath "\$SOURCE_PACKAGES_DIR"' "$archive" || fail "Archive verifier must reuse the SwiftPM package cache"
  rg -q 'Apple Distribution' "$signing" || fail "Signing prerequisite verifier must check for an Apple Distribution identity"
  rg -q 'DEVELOPMENT_TEAM.*found in the local keychain' "$signing" || fail "Signing prerequisite verifier must require a distribution identity for the configured team"
  rg -q 'EXPECTED_DEVELOPMENT_TEAM' "$signing" || fail "Signing prerequisite verifier must support an expected team guard"
  rg -q 'run_xcodebuild_with_timeout\.sh' "$signing" || fail "Signing prerequisite verifier must run xcodebuild with a timeout"
  rg -q -- '-clonedSourcePackagesDirPath "\$SOURCE_PACKAGES_DIR"' "$signing" || fail "Signing prerequisite verifier must reuse the SwiftPM package cache"
  rg -q 'ARCHIVE_PATH' "$signed_artifacts" || fail "Signed artifact verifier must require an archive path"
  rg -q 'EXPORT_PATH' "$signed_artifacts" || fail "Signed artifact verifier must support exported IPA verification"
  rg -q 'codesign -dv' "$signed_artifacts" || fail "Signed artifact verifier must inspect app signatures"
  rg -q 'Apple Distribution' "$signed_artifacts" || fail "Signed artifact verifier must require Apple Distribution signing"
  rg -q 'embedded.mobileprovision' "$signed_artifacts" || fail "Signed artifact verifier must inspect embedded provisioning profiles"
  rg -q 'ApplicationProperties:SigningIdentity' "$signed_artifacts" || fail "Signed artifact verifier must inspect archive signing identity metadata"
  rg -q 'assert_dsym_matches_binary' "$signed_artifacts" || fail "Signed artifact verifier must match dSYM UUIDs with the app binary"
  rg -q 'assert_privacy_manifest_declarations' "$signed_artifacts" || fail "Signed artifact verifier must validate bundled PrivacyInfo declarations"
  rg -q 'codesign --verify --strict' "$signed_artifacts" || fail "Signed artifact verifier must strictly verify code signatures"
  rg -q 'assert_signature_team_matches_profile' "$signed_artifacts" || fail "Signed artifact verifier must compare code signature TeamIdentifier with the provisioning profile"
  rg -q 'codesign -d --entitlements' "$signed_artifacts" || fail "Signed artifact verifier must inspect signed entitlements"
  rg -q 'code signature entitlements match the embedded provisioning profile' "$signed_artifacts" || fail "Signed artifact verifier must compare signed entitlements with the embedded provisioning profile"
  rg -q 'get-task-allow' "$signed_artifacts" || fail "Signed artifact verifier must reject debug provisioning profiles"
  rg -q 'ProvisionsAllDevices' "$signed_artifacts" || fail "Signed artifact verifier must reject enterprise all-devices profiles"
  rg -q 'ExpirationDate' "$signed_artifacts" || fail "Signed artifact verifier must check provisioning profile expiration"
  rg -q 'unzip -q "\$IPA_PATH"' "$signed_artifacts" || fail "Signed artifact verifier must inspect exported IPA contents"
  rg -q 'assert_dsym_matches_binary' "$archive" || fail "Unsigned archive verifier must match dSYM UUIDs with the app binary"
  rg -q 'assert_privacy_manifest_declarations' "$archive" || fail "Unsigned archive verifier must validate bundled PrivacyInfo declarations"
  rg -q 'assert_privacy_manifest_declarations' "$device_release" || fail "Device Release build verifier must validate bundled PrivacyInfo declarations"
  assert_plist_value "$export_options" "method" "app-store-connect"
  assert_plist_value "$export_options" "destination" "export"
  assert_plist_value "$export_options" "distributionBundleIdentifier" "com.claracore.mobile"
  assert_plist_value "$export_options" "manageAppVersionAndBuildNumber" "false"
  assert_plist_value "$export_options" "signingStyle" "automatic"
  rg -q 'xcodebuild' "$export_signed" || fail "Export script must call xcodebuild"
  rg -q -- '-exportArchive' "$export_signed" || fail "Export script must run xcodebuild -exportArchive"
  rg -q 'verify_signed_app_store_artifacts\.sh' "$export_signed" || fail "Export script must verify produced signed artifacts"
  rg -q 'verify_app_store_readiness\.sh' "$submission_ready" || fail "Final submission verifier must run the local readiness gate"
  rg -q 'verify_app_store_signing_prerequisites\.sh' "$submission_ready" || fail "Final submission verifier must run the signing prerequisite gate"
  rg -Fq 'RUN_SIGNED_ARTIFACTS="${RUN_SIGNED_ARTIFACTS:-1}"' "$submission_ready" || fail "Final submission verifier must require signed artifact validation by default"
  rg -q 'RUN_SIGNED_ARTIFACTS=0 explicitly' "$submission_ready" || fail "Final submission verifier must document explicit pre-certificate dry runs"
  rg -q 'verify_signed_app_store_artifacts\.sh' "$submission_ready" || fail "Final submission verifier must run the signed artifact gate by default"
  rg -q 'RUN_TRACKED_ARTIFACTS="\$\{RUN_TRACKED_ARTIFACTS:-1\}"' "$submission_ready" || fail "Final submission verifier must require tracked release artifacts by default"
  rg -q 'verify_release_artifacts_tracked\.sh' "$submission_ready" || fail "Final submission verifier must run the tracked-artifacts gate by default"
  rg -q 'RUN_CLEAN_WORKTREE="\$\{RUN_CLEAN_WORKTREE:-1\}"' "$submission_ready" || fail "Final submission verifier must require a clean release worktree by default"
  rg -q 'verify_release_worktree_clean\.sh' "$submission_ready" || fail "Final submission verifier must run the clean-worktree gate by default"
  rg -q 'verify_public_app_store_docs\.sh' "$submission_ready" || fail "Final submission verifier must run the public docs gate"
  rg -q 'verify_app_store_screenshots\.sh' "$submission_ready" || fail "Final submission verifier must run the screenshot package gate"
  rg -q 'MIN_SCREENSHOTS_PER_DEVICE="\$\{MIN_SCREENSHOTS_PER_DEVICE:-8\}"' "$submission_ready" || fail "Final submission verifier must require the full first-release screenshot count by default"
  rg -q 'env MIN_SCREENSHOTS_PER_DEVICE="\$MIN_SCREENSHOTS_PER_DEVICE"' "$submission_ready" || fail "Final submission verifier must pass the screenshot count requirement to the screenshot verifier"
  rg -q 'enabled_gate_count' "$submission_ready" || fail "Final submission verifier must count enabled gates"
  rg -q 'normalize_bool' "$submission_ready" || fail "Final submission verifier must reject ambiguous RUN_* values"
  rg -q 'assert_final_gate_environment' "$submission_ready" || fail "Final submission verifier must validate its environment before running gates"
  rg -q 'MIN_SCREENSHOTS_PER_DEVICE must be from 1 to 10' "$submission_ready" || fail "Final submission verifier must bound the final screenshot count requirement"
  rg -q 'ran zero gates' "$submission_ready" || fail "Final submission verifier must reject zero-gate no-op runs"
  rg -q 'all_required_gates_enabled' "$submission_ready" || fail "Final submission verifier must distinguish complete runs from partial runs"
  rg -q 'partial submission readiness run' "$submission_ready" || fail "Final submission verifier must warn when any gate is disabled"
  rg -q 'local gate is upload-ready' "$submission_ready" || fail "Final submission verifier must reserve upload-ready wording for complete runs"
  rg -q 'Failing gates:' "$submission_ready" || fail "Final submission verifier must summarize all failing gates"
  rg -q 'Next action:' "$submission_ready" || fail "Final submission verifier must print a concrete next action for each failing gate"
  rg -q 'Apple Developer Program team' "$submission_ready" || fail "Final submission verifier must explain signing prerequisite failures"
  rg -q 'ARCHIVE_PATH=/path/to/ClaraCoreMobile\.xcarchive' "$submission_ready" || fail "Final submission verifier must explain signed artifact failures"
  rg -q 'nonduplicate final screenshots' "$submission_ready" || fail "Final submission verifier must explain final screenshot package failures"
  rg -q 'require_exact_github_match' "$public_docs" || fail "Public docs verifier must require exact local/public matches for GitHub fallback URLs"
  rg -q 'require_exact_github_material' "$public_docs" || fail "Public docs verifier must check all App Store material files for GitHub fallback URLs"
  rg -q 'docs/app-store/index\.md' "$public_docs" || fail "Public docs verifier must check the App Store materials index"
  rg -q 'docs/app-store/app-privacy-labels\.md' "$public_docs" || fail "Public docs verifier must check App Privacy labels"
  rg -q 'docs/app-store/export-options-app-store-connect\.plist' "$public_docs" || fail "Public docs verifier must check export options"
  rg -q 'non-sensitive organization engine status' "$public_docs" || fail "Public docs verifier must check Support diagnostics disclose non-sensitive engine status"
  rg -q 'provider names, Base URLs, model names, or model provider configuration' "$public_docs" || fail "Public docs verifier must check Support diagnostics exclude model provider details"
  rg -q 'require_absent' "$public_docs" || fail "Public docs verifier must reject disallowed App Store positioning"
  rg -q 'third-party AI processing notice' "$public_docs" || fail "Public docs verifier must guard against AI-processing wording"
  rg -q '第三方 AI' "$public_docs" || fail "Public docs verifier must guard against Chinese AI-processing wording"
  rg -q '"\$ROOT_DIR/scripts/run_xcodebuild_with_timeout\.sh" "\$XCODEBUILD_TIMEOUT_SECONDS" "\$BUILD_LOG"' "$ROOT_DIR/scripts/verify_app_store_readiness.sh" || fail "Readiness gate must run its Release simulator xcodebuild with a timeout"
  rg -q -- '-clonedSourcePackagesDirPath "\$SOURCE_PACKAGES_DIR"' "$ROOT_DIR/scripts/verify_app_store_readiness.sh" || fail "Readiness gate must reuse the SwiftPM package cache"
  rg -q 'CONFIGURATION="\$\{CONFIGURATION:-Release\}"' "$smoke" || fail "Simulator launch smoke must default to Release builds"
  rg -q 'CONFIGURATION[[:space:]]+Xcode build configuration\. Default: Release' "$smoke" || fail "Simulator launch smoke help must document the Release default"
  rg -q 'scripts/verify_unit_tests\.sh' "$submission" || fail "Submission checklist must include the XCTest verifier"
  rg -q 'scripts/verify_public_app_store_docs\.sh' "$submission" || fail "Submission checklist must include the public App Store docs verifier"
  rg -q 'exactly match the local release documents' "$submission" || fail "Submission checklist must require exact public/local docs match for GitHub fallback URLs"
  rg -q 'scripts/smoke_simulator_launch\.sh' "$submission" || fail "Submission checklist must include the simulator launch smoke check"
  rg -q 'scripts/verify_device_release_build\.sh' "$submission" || fail "Submission checklist must include the device Release build verifier"
  rg -q 'scripts/verify_app_store_archive\.sh' "$submission" || fail "Submission checklist must include the unsigned archive verifier"
  rg -q 'scripts/verify_app_store_signing_prerequisites\.sh' "$submission" || fail "Submission checklist must include the signing prerequisite verifier"
  rg -q 'Team ID matches `DEVELOPMENT_TEAM`' "$submission" || fail "Submission checklist must require the distribution certificate to match the configured team"
  rg -q 'scripts/export_signed_app_store_archive\.sh' "$submission" || fail "Submission checklist must include the signed archive export script"
  rg -q 'export-options-app-store-connect\.plist' "$submission" || fail "Submission checklist must document the App Store Connect export options plist"
  rg -q 'scripts/verify_signed_app_store_artifacts\.sh' "$submission" || fail "Submission checklist must include the signed artifact verifier"
  rg -q 'code-signature TeamIdentifier and signed entitlements match the embedded provisioning profile' "$submission" || fail "Submission checklist must document code-signature TeamIdentifier validation"
  rg -q 'RUN_SIGNED_ARTIFACTS=0' "$submission" || fail "Submission checklist must reserve RUN_SIGNED_ARTIFACTS=0 for pre-certificate dry runs only"
  rg -q 'scripts/verify_app_store_submission_ready\.sh' "$submission" || fail "Submission checklist must include the final submission verifier"
  rg -q 'MIN_SCREENSHOTS_PER_DEVICE=8 scripts/verify_app_store_screenshots\.sh' "$submission" || fail "Submission checklist must require the full first-release screenshot package before upload"
  rg -q 'Run the final local submission gate after the signed archive/export, public documents, screenshots, metadata, review notes, and availability choices are all final' "$submission" || fail "Submission checklist must run the final submission verifier only after all upload materials are final"
  rg -q 'ARCHIVE_PATH=/path/to/ClaraCoreMobile\.xcarchive EXPORT_PATH=/path/to/export scripts/verify_app_store_submission_ready\.sh' "$submission" || fail "Submission checklist final verifier example must include ARCHIVE_PATH"
  rg -q 'scripts/verify_unit_tests\.sh' "$checklist" || fail "Manual E2E checklist must include the XCTest verifier"
  rg -q 'scripts/smoke_simulator_launch\.sh' "$checklist" || fail "Manual E2E checklist must include the simulator launch smoke check"
  rg -q 'unsaved model configuration changes and still calculates enablement from the last saved configuration' "$checklist" || fail "Manual E2E checklist must verify unsaved model configuration drafts do not change active engine status"
  rg -q 'Unsaved model configuration edits are clearly labeled as unsaved' "$checklist" || fail "Manual E2E pass criteria must require clear unsaved model configuration status"
  pass "XCTest, simulator launch smoke, device Release build, and unsigned archive checks are available, documented, and preserve failure logs"
}

assert_mainland_china_release_guidance() {
  local metadata="$ROOT_DIR/docs/app-store/app-store-connect-metadata.md"
  local submission="$ROOT_DIR/docs/app-store/app-store-submission.md"
  rg -q 'Exclude mainland China for the first public release unless ICP/app filing requirements are confirmed and satisfied\.' "$metadata" || fail "Metadata must keep first-release mainland China exclusion guidance"
  rg -q 'If there is no confirmed ICP filing and no mainland-China compliance review, do not include mainland China in the first public App Store launch\.' "$submission" || fail "Submission checklist must keep mainland China compliance recommendation"
  pass "Mainland China first-release availability guidance is present"
}

assert_app_review_privacy_boundaries() {
  local metadata="$ROOT_DIR/docs/app-store/app-store-connect-metadata.md"
  local submission="$ROOT_DIR/docs/app-store/app-store-submission.md"
  local screenshot_plan="$ROOT_DIR/docs/app-store/screenshot-plan.md"
  local privacy_labels="$ROOT_DIR/docs/app-store/app-privacy-labels.md"
  local index="$ROOT_DIR/docs/app-store/index.md"
  [[ -f "$privacy_labels" ]] || fail "App Privacy labels source of truth is missing at $privacy_labels"
  rg -q "^Date: $RELEASE_DOC_DATE$" "$privacy_labels" || fail "App Privacy labels must declare Date: $RELEASE_DOC_DATE"
  rg -q 'docs/app-store/app-privacy-labels\.md' "$metadata" || fail "Metadata must point to the App Privacy labels source of truth"
  rg -q 'docs/app-store/app-privacy-labels\.md' "$submission" || fail "Submission checklist must point to the App Privacy labels source of truth"
  rg -q '\[App Store Connect Metadata\]\(app-store-connect-metadata\.md\)' "$index" || fail "App Store index must link App Store Connect metadata"
  rg -q '\[App Privacy Labels\]\(app-privacy-labels\.md\)' "$index" || fail "App Store index must link App Privacy labels"
  rg -q '\[App Store Connect Export Options\]\(export-options-app-store-connect\.plist\)' "$index" || fail "App Store index must link export options plist"
  rg -q 'No, we do not use this app to track users\.' "$privacy_labels" || fail "App Privacy labels must explicitly declare no tracking"
  rg -q 'No developer-operated collection\.' "$privacy_labels" || fail "App Privacy labels must declare no developer-operated collection"
  rg -q 'No developer-operated server collection' "$privacy_labels" || fail "App Privacy labels must distinguish third-party provider processing from ClaraCore collection"
  rg -q 'ThisDeviceOnly iOS Keychain' "$privacy_labels" || fail "App Privacy labels must describe API key storage"
  rg -q 'Copy Diagnostics action copies a local support block to the user' "$privacy_labels" || fail "App Privacy labels must describe local-only diagnostics copy behavior"
  rg -q 'Contact Info' "$privacy_labels" || fail "App Privacy labels must list categories to leave unselected"
  rg -q 'Usage Data' "$privacy_labels" || fail "App Privacy labels must list Usage Data as unselected"
  rg -q 'Diagnostics' "$privacy_labels" || fail "App Privacy labels must list Diagnostics as unselected"
  rg -q 'copy or share a complete original Archive entry' "$metadata" || fail "App Store metadata review notes must disclose Archive original copy/share as user-controlled data egress"
  rg -q 'copy or share a complete original Archive entry' "$submission" || fail "Submission review notes must disclose Archive original copy/share as user-controlled data egress"
  rg -q 'Import screen with role card selector, source input, paste/file buttons, `本次整理机制`, and the direct Settings action' "$metadata" || fail "App Store metadata screenshot list must require Import to show active mechanism and Settings action"
  rg -q 'Import screen with role card selector, source input, paste/file buttons, `本次整理机制`, and the direct Settings action' "$submission" || fail "Submission screenshot list must require Import to show active mechanism and Settings action"
  rg -q 'Copying a recall package to the clipboard or copying/sharing a complete original Archive entry is user-directed device behavior, not developer-operated server collection' "$metadata" || fail "Metadata privacy labels must distinguish user-directed clipboard/share from developer collection"
  rg -q 'Copying a recall package to the clipboard or copying/sharing a complete original Archive entry is user-directed device behavior, not developer-operated server collection' "$submission" || fail "Submission privacy labels must distinguish user-directed clipboard/share from developer collection"
  rg -q 'not collected by ClaraCore servers' "$metadata" || fail "Metadata privacy labels must state user-directed copy/share is not ClaraCore server collection"
  rg -q 'not collected by ClaraCore servers' "$submission" || fail "Submission privacy labels must state user-directed copy/share is not ClaraCore server collection"
  rg -q 'Confirm the notes disclose the user-controlled copy/share path for complete original Archive entries' "$submission" || fail "Submission checklist must remind submitter to disclose Archive original copy/share in review notes"
  rg -q 'external conversation app' "$screenshot_plan" || fail "Screenshot plan must use conversation-app wording for recall screenshots"
  if rg -q 'third-party AI processing notice|third-party AI consent|AI processing|第三方 AI|AI 处理' "$ROOT_DIR/docs/app-store"; then
    fail "Public App Store materials must use external-model wording instead of AI-processing positioning"
  fi
  if rg -q 'external AI app|other AI apps' "$screenshot_plan"; then
    fail "Screenshot plan must avoid AI-app positioning in public screenshot guidance"
  fi
  pass "App Privacy labels, App Review notes, and screenshot privacy wording are aligned"
}

unique_project_setting() {
  local key="$1"
  local values
  values="$(awk -v key="$key" '$1 == key { value = $3; gsub(/;/, "", value); print value }' "$PROJECT_FILE" | sort -u)"
  local count
  count="$(printf '%s\n' "$values" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$count" == "1" ]] || fail "$key must have exactly one value across project configurations, got: ${values:-<none>}"
  printf '%s\n' "$values"
}

assert_version_helper_matches_project() {
  local helper="$ROOT_DIR/scripts/set_app_version.sh"
  [[ -x "$helper" ]] || fail "$helper must exist and be executable"
  "$helper" --check "$EXPECTED_MARKETING_VERSION" "$EXPECTED_BUILD_NUMBER" >/dev/null
  pass "Version helper matches MARKETING_VERSION=$EXPECTED_MARKETING_VERSION CURRENT_PROJECT_VERSION=$EXPECTED_BUILD_NUMBER"
}

assert_app_store_metadata() {
  python3 - "$ROOT_DIR/docs/app-store/app-store-connect-metadata.md" "$PRIVACY_POLICY_URL" "$SUPPORT_URL" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_privacy_url = sys.argv[2]
expected_support_url = sys.argv[3]
text = path.read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def extract_labeled_block(label: str) -> str:
    pattern = rf"{re.escape(label)}:\n\n```text\n(.*?)\n```"
    match = re.search(pattern, text, re.DOTALL)
    if not match:
        fail(f"Missing metadata field: {label}")
    return match.group(1).strip()


def extract_heading_block(heading: str) -> str:
    pattern = rf"## {re.escape(heading)}\n\n```text\n(.*?)\n```"
    match = re.search(pattern, text, re.DOTALL)
    if not match:
        fail(f"Missing metadata section: {heading}")
    return match.group(1).strip()


fields = {
    "Name": (extract_labeled_block("Name"), 30),
    "Subtitle": (extract_labeled_block("Subtitle"), 30),
    "Promotional Text": (extract_heading_block("Promotional Text"), 170),
    "Description": (extract_heading_block("Description"), 4000),
    "Keywords": (extract_heading_block("Keywords"), 100),
}

privacy_url = extract_labeled_block("Privacy Policy URL")
support_url = extract_labeled_block("Support URL")
if privacy_url != expected_privacy_url:
    fail(f"Privacy Policy URL mismatch: expected {expected_privacy_url}, got {privacy_url}")
if support_url != expected_support_url:
    fail(f"Support URL mismatch: expected {expected_support_url}, got {support_url}")

category = extract_labeled_block("Category")
content_rights = extract_labeled_block("Content rights")
age_rating_guidance = extract_labeled_block("Age rating guidance")
initial_recommendation = extract_labeled_block("Initial recommendation")
pricing_reason = extract_labeled_block("Reason")
if category != "Productivity":
    fail(f"Category must stay Productivity for the first release, got {category!r}")
for expected in [
    "user-selected text",
    "public share links",
    "text files",
    "does not include third-party copyrighted media assets",
]:
    if expected not in content_rights:
        fail(f"Content rights guidance must mention {expected!r}")
for expected in [
    "No unrestricted web browser.",
    "No gambling, contests, or commerce.",
    "No medical diagnosis, therapy, or crisis intervention.",
    "User-generated imported text may contain arbitrary content",
]:
    if expected not in age_rating_guidance:
        fail(f"Age rating guidance must mention {expected!r}")
for expected in [
    "Free, no in-app purchases.",
    "Exclude mainland China for the first public release",
]:
    if expected not in initial_recommendation:
        fail(f"Initial pricing/availability recommendation must mention {expected!r}")
if "reduce compliance uncertainty" not in pricing_reason:
    fail("Pricing and availability reason must keep the compliance rationale")

review_notes = extract_heading_block("App Review Notes")
if len(review_notes) > 4000:
    fail(f"App Review Notes is {len(review_notes)} characters; limit is 4000")

placeholder_pattern = re.compile(r"\[[A-Z0-9_ -]{3,}\]")
for label, value in {**{key: item[0] for key, item in fields.items()}, "App Review Notes": review_notes}.items():
    if placeholder_pattern.search(value):
        fail(f"{label} still contains bracketed placeholder text")

for label, (value, limit) in fields.items():
    length = len(value)
    if length == 0:
        fail(f"{label} is empty")
    if length > limit:
        fail(f"{label} is {length} characters; limit is {limit}")
    if label == "Keywords":
        keywords = [item.strip() for item in value.split(",")]
        if any(not item for item in keywords):
            fail("Keywords contains an empty keyword")
        if len(set(keywords)) != len(keywords):
            fail("Keywords contains duplicates")
    print(f"OK: {label} length {length}/{limit}")

public_positioning = "\n".join([
    fields["Subtitle"][0],
    fields["Promotional Text"][0],
    fields["Description"][0],
    fields["Keywords"][0],
])
for disallowed in [
    "AI 对话",
    "AI 应用",
    "AI,",
    "external AI app",
    "AI conversation material",
]:
    if disallowed in public_positioning:
        fail(f"Public App Store positioning should use conversation/context wording, not {disallowed!r}")
if "对话上下文整理" not in fields["Subtitle"][0]:
    fail("Subtitle should position ClaraCore as conversation/context organization")

print("OK: Privacy Policy URL matches readiness source of truth")
print("OK: Support URL matches readiness source of truth")
print("OK: Category, content rights, age rating, and availability guidance are present")
print("OK: Public App Store copy uses conversation/context positioning")
print(f"OK: App Review Notes length {len(review_notes)}/4000")
PY
}

cd "$ROOT_DIR"

log "Checking public support and privacy URLs"
assert_http_200 "$PRIVACY_POLICY_URL"
assert_http_200 "$SUPPORT_URL"
assert_http_200 "$SUPPORT_CONTACT_URL"
assert_in_app_public_urls

log "Checking GitHub Pages workflow trigger"
assert_pages_workflow_manual_only

log "Checking release document dates"
assert_document_dates_current
assert_in_app_privacy_copy
assert_in_app_support_copy

log "Checking screenshot plan"
assert_screenshot_plan
assert_simulator_smoke_check_documented

log "Checking mainland China release guidance"
assert_mainland_china_release_guidance

log "Checking App Review privacy boundaries"
assert_app_review_privacy_boundaries

log "Checking project version settings"
EXPECTED_MARKETING_VERSION="$(unique_project_setting MARKETING_VERSION)"
EXPECTED_BUILD_NUMBER="$(unique_project_setting CURRENT_PROJECT_VERSION)"
pass "MARKETING_VERSION is consistently $EXPECTED_MARKETING_VERSION"
pass "CURRENT_PROJECT_VERSION is consistently $EXPECTED_BUILD_NUMBER"
assert_version_helper_matches_project

log "Linting plist and project files"
plutil -lint \
  "$ROOT_DIR/ClaraCoreMobile/PrivacyInfo.xcprivacy" \
  "$PROJECT_FILE" >/dev/null
pass "Privacy manifest and Xcode project plist syntax are valid"

log "Checking launch preflight settings"
assert_scene_manifest_not_generated

log "Checking Keychain API key storage"
assert_database_backup_exclusion
assert_local_data_clear_control
assert_startup_failure_recovery
assert_keychain_accessibility
assert_model_provider_url_policy
assert_local_rulebook_disclosure
assert_destructive_delete_confirmations
assert_recall_copy_boundary
assert_archive_copy_boundary
assert_import_size_guard
assert_url_import_https_guard
assert_reflection_runner_segment_guard
assert_user_visible_errors_are_presented_safely

log "Running XCTest suite"
"$ROOT_DIR/scripts/verify_unit_tests.sh"

log "Checking privacy manifest declarations"
assert_privacy_manifest_declarations "$ROOT_DIR/ClaraCoreMobile/PrivacyInfo.xcprivacy" "Source"

log "Checking App Store icon asset"
APP_ICON="$ROOT_DIR/ClaraCoreMobile/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
[[ -f "$APP_ICON" ]] || fail "App Store icon not found at $APP_ICON"
assert_sips_property "$APP_ICON" "pixelWidth" "1024"
assert_sips_property "$APP_ICON" "pixelHeight" "1024"
assert_sips_property "$APP_ICON" "hasAlpha" "no"

log "Checking App Store Connect metadata"
assert_app_store_metadata

log "Scanning committed source for common real API key patterns"
if rg -n --hidden \
  -g '!/.git/**' \
  -g '!*.xcresult/**' \
  -g '!DerivedData/**' \
  -e 'sk-proj-[A-Za-z0-9_-]{20,}' \
  -e 'sk-[A-Za-z0-9_-]{20,}' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'AIza[0-9A-Za-z_-]{35}' \
  "$ROOT_DIR"; then
  fail "Potential real API key pattern found. Remove secrets before submission."
fi
pass "No common real API key patterns found"

log "Building Release simulator app with App Store validation"
BUILD_LOG="$DERIVED_DATA/xcodebuild-release.log"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-900}"
mkdir -p "$SOURCE_PACKAGES_DIR"
if ! "$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh" "$XCODEBUILD_TIMEOUT_SECONDS" "$BUILD_LOG" -- \
  xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  build; then
  tail -n 120 "$BUILD_LOG" >&2
  fail "Release simulator build failed or timed out after ${XCODEBUILD_TIMEOUT_SECONDS}s. Full log: $BUILD_LOG"
fi
pass "Release simulator build succeeded"

APP_PATH="$DERIVED_DATA/Build/Products/Release-iphonesimulator/ClaraCoreMobile.app"
INFO_PLIST="$APP_PATH/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"

[[ -d "$APP_PATH" ]] || fail "Built app bundle not found at $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "Built Info.plist not found"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "Built PrivacyInfo.xcprivacy not found"
pass "Built bundle contains Info.plist and PrivacyInfo.xcprivacy"
assert_privacy_manifest_declarations "$PRIVACY_MANIFEST" "Release simulator bundle"

log "Checking built app metadata"
assert_plist_value "$INFO_PLIST" "CFBundleIdentifier" "com.claracore.mobile"
assert_plist_value "$INFO_PLIST" "CFBundleShortVersionString" "$EXPECTED_MARKETING_VERSION"
assert_plist_value "$INFO_PLIST" "CFBundleVersion" "$EXPECTED_BUILD_NUMBER"
assert_plist_value "$INFO_PLIST" "ITSAppUsesNonExemptEncryption" "false"
assert_plist_key_absent "$INFO_PLIST" "UIApplicationSceneManifest"

log "Building Release device app without signing"
"$ROOT_DIR/scripts/verify_device_release_build.sh"

log "Running Release simulator launch smoke"
"$ROOT_DIR/scripts/smoke_simulator_launch.sh"

log "Creating unsigned App Store archive structure"
"$ROOT_DIR/scripts/verify_app_store_archive.sh"

log "App Store readiness checks passed"
