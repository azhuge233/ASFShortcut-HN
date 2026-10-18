import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { AppStorageV2, window, KeyboardAvoidMode } from '@kit.ArkUI';

import Logger from '../common/utils/Logger';
import { DB } from '../common/utils/DB';
import CommonConstants from '../common/constants/CommonConstants';
import { PM } from '../common/utils/PM';
import { AppSettingsManager } from '../common/utils/AppSettingsManager';
import { AppSettings } from '../model/AppSettings';

export default class EntryAbility extends UIAbility {
    private LOG_TAG = "[EntryAbility]";

    private targetPage: string = 'pages/Index'; // 指定页面，默认为 Index
    private currentWindowStage: window.WindowStage | null = null;

    private db = DB.getInstance();
    private pm = PM.getInstance();
    private aSM = AppSettingsManager.getInstance();

    private static readonly VALID_TARGET_PAGES: Set<string> = new Set([
        'pages/Index',
        'pages/AddCommand',
        'pages/EditPage',
        'pages/ASFSettingsPage',
        'pages/MorePage',
        'pages/ColorModeSettingsPage',
        'pages/SingleCommandFormEdit',
        'pages/MultipleCommandsFormEdit'
    ]);

    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        Logger.debug(this.LOG_TAG, 'onCreate()');

        this.init(); // 持久化存储初始化

        if(want.parameters?.params) this.handleFormWant(want);
        else if (want.parameters?.isFromShortcut) this.handleShortcutWant(want);
        else Logger.debug(this.LOG_TAG, `onCreate() 应用图标转入`);

        Logger.debug(this.LOG_TAG, `onCreate() targetPage: ${this.targetPage}`);
    }

    onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        Logger.debug(this.LOG_TAG, 'onNewWant()');

        if(want.parameters?.params) {
            this.handleFormWant(want);
            // 手动进入目标页面
            this.loadContent();
        } else if(want.parameters?.isFromShortcut) this.handleShortcutWant(want);
        else Logger.debug(this.LOG_TAG, `onNewWant() 应用图标转入`);

        Logger.debug(this.LOG_TAG, `onNewWant() targetPage: ${this.targetPage}`);
    }

    onDestroy(): void {
        Logger.debug(this.LOG_TAG, 'onDestroy()');
    }

    async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
        // Main window is created, set main page for this ability
        Logger.debug(this.LOG_TAG, 'onWindowStageCreate()');

        // 设置当前窗口为传入窗口
        if (this.currentWindowStage === null) this.currentWindowStage = windowStage;

        // 从首选项加载并设置颜色模式
        await this.setColorMode();

        // 加载页面
        this.loadContent();
    }

    onWindowStageDestroy(): void {
        // Main window is destroyed, release UI related resources
        Logger.debug(this.LOG_TAG, 'onWindowStageDestroy()');
    }

    onForeground(): void {
        // Ability has brought to foreground
        Logger.debug(this.LOG_TAG, 'onForeground()');
    }

    onBackground(): void {
        // Ability has back to background
        Logger.debug(this.LOG_TAG, 'onBackground()');
    }

    private init() {
        const appContext = this.context.getApplicationContext();
        this.aSM.init(appContext);
        this.db.init(appContext);
        this.pm.init(appContext);
    }

    private loadContent(): void {
        if(this.currentWindowStage) {
            this.currentWindowStage.loadContent(this.targetPage, (err) => {
                try {
                    this.currentWindowStage?.getMainWindowSync().getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET_WITH_CARET);
                } catch (err) {
                    Logger.error(this.LOG_TAG, `loadContent() 设置软键盘避让失败`);
                }

                if (err && err.code) {
                    Logger.error(this.LOG_TAG, `loadContent() 加载 ${this.targetPage} 失败 ${JSON.stringify(err)}`,);
                    return;
                }
                Logger.debug(this.LOG_TAG, `loadContent() 加载 ${this.targetPage} 成功`);
            });
        } else Logger.warn(this.LOG_TAG, 'loadContent() 当前窗口为空');
    }

    private handleFormWant(want: Want): void {
        Logger.debug(this.LOG_TAG, `桌面卡片转入`);

        try {
            const rawParams = want?.parameters?.params;
            if (typeof rawParams !== 'string') {
                Logger.warn(this.LOG_TAG, `handleFormWant() 参数为空`);
                this.targetPage = 'pages/Index';
                return;
            }

            const params = JSON.parse(rawParams) as Record<string, Object>;
            const targetPage = params['targetPage'];

            if (typeof targetPage === 'string' && EntryAbility.VALID_TARGET_PAGES.has(targetPage)) {
                this.targetPage = targetPage;
            } else {
                Logger.warn(this.LOG_TAG, `handleFormWant() 非法目标页面，使用默认页面`);
                this.targetPage = 'pages/Index';
            }

            const formID = params['formID'];
            if (typeof formID === 'string' && formID.trim() !== '') {
                AppStorage.setOrCreate(CommonConstants.AppStorage_KEY_FormID, formID);
            } else {
                Logger.warn(this.LOG_TAG, `handleFormWant() formID 为空`);
            }
        } catch (err) {
            Logger.error(this.LOG_TAG, `handleFormWant() 解析失败, ${err}`);
            this.targetPage = 'pages/Index';
        }
    }

    private handleShortcutWant(want: Want): void {
        Logger.debug(this.LOG_TAG, `长按快捷方式转入`);
        const shortCutKey = want?.parameters?.shortCutKey;
        if (typeof shortCutKey === 'string' && shortCutKey.trim() !== '') {
            AppStorage.setOrCreate(CommonConstants.AppStorage_KEY_ShortcutPath, shortCutKey);
        } else {
            Logger.warn(this.LOG_TAG, `handleShortcutWant() 快捷方式参数为空`);
        }
    }

    private async setColorMode(): Promise<void> {
        try {
            let appSettings = await this.aSM.get();

            if(!appSettings) {
                appSettings = new AppSettings(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
                await this.aSM.set(appSettings);
            }

            this.context.getApplicationContext().setColorMode(appSettings.colorMode);

            AppStorageV2.connect(AppSettings, CommonConstants.AppStorage_KEY_AppSettings, () => appSettings);

            Logger.debug(this.LOG_TAG, `setColorMode() 窗口颜色设置: ${appSettings.colorMode}`)
        } catch (err) {
            Logger.error(this.LOG_TAG, `setColorMode() 设置窗口颜色模式失败, ${err}`);
        }
    }
}