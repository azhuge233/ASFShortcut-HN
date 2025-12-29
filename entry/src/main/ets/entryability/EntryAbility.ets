import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { DB } from '../common/utils/DB';
import CommonConstants from '../common/constants/CommonConstants';
import { PM } from '../common/utils/PM';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
    private LOG_PREFIX = "[ASFShortcut]";
    private LOG_FORMAT = '%{public}s -> %{public}s';
    private LOG_TAG = "[EntryAbility]";

    private targetPage: string = 'pages/Index'; // 指定页面，默认为 Index
    private currentWindowStage: window.WindowStage | null = null;

    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        try {
            this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        } catch (err) {
            hilog.error(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, `Failed to set colorMode. Cause: ${JSON.stringify(err)}`);
        }
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onCreate');

        DB.getInstance().initDB(this.context);
        PM.getInstance().init(this.context);

        // 由卡片转入
        if(want?.parameters?.params) {
            let params: Record<string, Object> = JSON.parse(want.parameters.params as string);
            this.targetPage = params.targetPage as string;

            const formID = params.formID as string;

            if((formID ?? false) && formID.trim() !== '') AppStorage.setOrCreate(CommonConstants.AppStorage_KEY_FormID, formID);
        }

        // 由长按快捷方式转入
        if (want?.parameters?.isFromShortcut ?? false) AppStorage.setOrCreate('want', want);

        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, `onCreate targetPage: ${this.targetPage}`);
    }

    onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onNewWant');

        // 由卡片转入
        if(want?.parameters?.params) {
            let params: Record<string, Object> = JSON.parse(want.parameters.params as string);
            this.targetPage = params.targetPage as string;

            const formID = params.formID as string;

            if((formID ?? false) && formID.trim() !== '') AppStorage.setOrCreate(CommonConstants.AppStorage_KEY_FormID, formID);
        }

        // 由长按快捷方式转入
        if(want?.parameters?.isFromShortcut ?? false) AppStorage.setOrCreate('want', want);

        // 将当前 window 替换为新 window
        if (this.currentWindowStage !== null) {
            this.onWindowStageCreate(this.currentWindowStage);
        }

        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, `onNewWant targetPage: ${this.targetPage}`);
    }

    onDestroy(): void {
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onDestroy');
    }

    onWindowStageCreate(windowStage: window.WindowStage): void {
        // Main window is created, set main page for this ability
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onWindowStageCreate');

        // 创建新 window
        if (this.currentWindowStage === null) {
            this.currentWindowStage = windowStage;
        }

        // 加载指定页面 targetPage
        windowStage.loadContent(this.targetPage, (err) => {
            if (err.code) {
                hilog.error(DOMAIN, this.LOG_PREFIX,this.LOG_FORMAT, this.LOG_TAG, `Failed to load the content. Cause: ${JSON.stringify(err)}`, );
                return;
            }
            hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Succeeded in loading the content.');
        });
    }

    onWindowStageDestroy(): void {
        // Main window is destroyed, release UI related resources
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onWindowStageDestroy');
    }

    onForeground(): void {
        // Ability has brought to foreground
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onForeground');
    }

    onBackground(): void {
        // Ability has back to background
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onBackground');
    }
}