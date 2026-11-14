import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { AppStorageV2, window, KeyboardAvoidMode } from '@kit.ArkUI';

import Logger from '../common/utils/Logger';
import { Database } from '../data/Database';
import CommonConstants from '../common/constants/CommonConstants';
import { FormBindingStore } from '../data/store/FormBindingStore';
import { AppSettingsStore } from '../data/store/AppSettingsStore';
import { toPlatformColorMode } from '../common/utils/ColorModeMapper';
import { AppSettings, ColorMode } from '../domain/model/AppSettings';
import PageContext from '../ui/common/PageContext';

/**
 * 卡片编辑窗口的基类（设计 §2.13）：两个编辑 Ability 归一化后无差异，本批收成
 * 基类 + 两个薄子类（子类只给 `logTag` 与 `targetPage`）。
 *
 * 基类装四件事：服务初始化、`formID` 解析、每窗口一份的 `LocalStorage` 参数通道（§2.6）、
 * 颜色模式应用与页面加载。
 *
 * 关闭语义一字不动：页面 `onPageHide` 的 `closeApplication` 与保存守卫（§2.7）都留在页面文件里。
 */
export abstract class CardEditAbilityBase extends UIAbility {
    // 子类只给这两处事实（日志标签、页面路径），生命周期钩子一个都不重写
    protected abstract readonly logTag: string;
    protected abstract readonly targetPage: string;

    private currentWindowStage: window.WindowStage | null = null;

    // formID 无效时关窗并停住：`terminateSelf` 是异步的，不停住的话页面会带着空 formID 建起来
    private stopped: boolean = false;

    // 每实例一份：一次性参数（formID）只在本窗口可见，进程级全局键在双编辑窗口下会互相覆盖
    private windowStorage: LocalStorage = new LocalStorage();

    private db = Database.getInstance();
    private pm = FormBindingStore.getInstance();
    private aSM = AppSettingsStore.getInstance();

    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        Logger.debug(this.logTag, 'onCreate()');

        this.initServices();

        const formID: string = this.readFormID(want);
        if (formID === '') {
            this.stopped = true;
        } else {
            this.windowStorage = this.createWindowStorage(formID);
        }

        Logger.debug(this.logTag, `onCreate() targetPage: ${this.targetPage}`);
    }

    // `multiton` 下正常不触发：保留只为形态与 1.7.1 一致，不新增行为
    onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        Logger.debug(this.logTag, 'onNewWant()');

        const formID: string = this.readFormID(want);
        if (formID !== '') this.windowStorage.setOrCreate(CommonConstants.APP_STORAGE_KEY_FORM_ID, formID);

        Logger.debug(this.logTag, `onNewWant() targetPage: ${this.targetPage}`);
    }

    onDestroy(): void {
        Logger.debug(this.logTag, 'onDestroy()');
    }

    async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
        Logger.debug(this.logTag, 'onWindowStageCreate()');

        // 设置当前窗口为传入窗口
        if (this.currentWindowStage === null) this.currentWindowStage = windowStage;

        // 从首选项加载并设置颜色模式（页面出现前生效，与 1.7.1 同顺序）
        await this.applyColorMode();

        // formID 无效：已调过 `closeApplication`，这里不再加载页面（设计 §2.13「关闭并停止」）
        if (this.stopped) {
            Logger.warn(this.logTag, 'onWindowStageCreate() formID 无效，不加载页面');
            return;
        }

        const stage: window.WindowStage | null = this.currentWindowStage;
        if (!stage) {
            Logger.warn(this.logTag, 'onWindowStageCreate() 当前窗口为空');
            return;
        }

        // 加载页面；参数通道随第二参交付（§2.6）
        this.loadContent(stage, this.windowStorage);
    }

    onWindowStageDestroy(): void {
        Logger.debug(this.logTag, 'onWindowStageDestroy()');
    }

    onForeground(): void {
        Logger.debug(this.logTag, 'onForeground()');
    }

    onBackground(): void {
        Logger.debug(this.logTag, 'onBackground()');
    }

    private initServices(): void {
        const appContext = this.context.getApplicationContext();
        this.aSM.init(appContext);
        this.db.init(appContext);
        this.pm.init(appContext);
    }

    // `want.parameters.formId` → formID；无效则关闭窗口并返回空串
    private readFormID(want: Want): string {
        const rawFormID = want.parameters?.formId;
        const formID: string = typeof rawFormID === 'string' ? rawFormID : '';

        Logger.debug(this.logTag, `编辑卡片，卡片 ID = ${formID}`);

        if (formID.trim() === '') {
            Logger.warn(this.logTag, 'readFormID() 卡片 ID 无效');
            PageContext.closeApplication(this.logTag, this.context);
            return '';
        }

        return formID;
    }

    // 每个 Ability 实例一份窗口存储；页面经 `getSharedLocalStorage()` 取到同一实例
    private createWindowStorage(formID: string): LocalStorage {
        const storage = new LocalStorage();

        storage.setOrCreate(CommonConstants.APP_STORAGE_KEY_FORM_ID, formID);

        return storage;
    }

    private loadContent(windowStage: window.WindowStage, storage: LocalStorage): void {
        windowStage.loadContent(this.targetPage, storage, (err) => {
            try {
                windowStage.getMainWindowSync().getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET_WITH_CARET);
            } catch (err) {
                Logger.error(this.logTag, `loadContent() 设置软键盘避让失败`);
            }

            if (err && err.code) {
                Logger.error(this.logTag, `loadContent() 加载 ${this.targetPage} 失败 ${JSON.stringify(err)}`);
                return;
            }
            Logger.debug(this.logTag, `loadContent() 加载 ${this.targetPage} 成功`);
        });
    }

    // 读设置 → 应用平台颜色模式 → 绑定 AppStorageV2 共享实例（颜色模式只有这一份，§2.9）
    private async applyColorMode(): Promise<void> {
        try {
            let appSettings = await this.aSM.get();

            if (!appSettings) {
                appSettings = new AppSettings(ColorMode.FOLLOW_SYSTEM);
                await this.aSM.set(appSettings);
            }

            this.context.getApplicationContext().setColorMode(toPlatformColorMode(appSettings.colorMode));

            AppStorageV2.connect(AppSettings, CommonConstants.APP_STORAGE_KEY_APP_SETTINGS, () => appSettings);

            Logger.debug(this.logTag, `applyColorMode() 窗口颜色设置: ${appSettings.colorMode}`);
        } catch (err) {
            Logger.error(this.logTag, `applyColorMode() 设置窗口颜色模式失败, ${err}`);
        }
    }
}
