class CommonConstants {
    public readonly DB_KEY_HOST_INFO_ADDRESS = 'Address';
    public readonly DB_KEY_HOST_INFO_PASSWORD = 'Password';

    public readonly VIBRATE_EFFECT_ID_SOFT = 'haptic.effect.soft';
    public readonly VIBRATE_EFFECT_ID_HARD = 'haptic.effect.hard';

    public readonly APP_STORAGE_KEY_SHORTCUT_PATH = 'path';
    public readonly APP_STORAGE_KEY_FORM_ID = 'formID';
    public readonly APP_STORAGE_KEY_APP_SETTINGS = "AppSettings";

    public readonly FORM_MESSAGE_RESTORE = 'restore';

    public readonly FORM_CALL_RUN = 'run';
    public readonly FORM_CALL_CANCEL = 'cancel';

    // 卡片侧硬超时（毫秒）：整个运行过程的上界
    public readonly FORM_RUN_TIMEOUT_MS = 15000;

    public readonly FORM_ACTION_ROUTER = 'router';
    public readonly FORM_ACTION_CALL = 'call';
    public readonly FORM_ACTION_MESSAGE = 'message';

    public readonly FORM_RESULT_MAP_KEY_SINGLE = 'single';
    public readonly FORM_RESULT_MAP_KEY_MULTIPLE = 'multiple';

    // 「关于」页两项的固定取值：仓库 origin 与其账户名（需求档依赖一节给出）
    public readonly OPEN_SOURCE_URL = 'https://github.com/azhuge233/ASFShortcut-HN';
    public readonly OPEN_SOURCE_AUTHOR = 'azhuge233';
}

export default new CommonConstants();
