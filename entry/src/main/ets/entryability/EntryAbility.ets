import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { DB } from '../common/utils/DB';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
    private LOG_PREFIX = "[ASFShortcut]";
    private LOG_FORMAT = '%{public}s -> %{public}s';
    private LOG_TAG = "[EntryAbility]";

    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        try {
            this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        } catch (err) {
            hilog.error(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, `Failed to set colorMode. Cause: ${JSON.stringify(err)}`);
        }
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onCreate');

        DB.getInstance().initDB(this.context);
    }

    onDestroy(): void {
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onDestroy');
    }

    onWindowStageCreate(windowStage: window.WindowStage): void {
        // Main window is created, set main page for this ability
        hilog.debug(DOMAIN, this.LOG_PREFIX, this.LOG_FORMAT, this.LOG_TAG, 'Ability onWindowStageCreate');

        windowStage.loadContent('pages/Index', (err) => {
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