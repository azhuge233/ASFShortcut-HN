class StyleConstants {
    public readonly FULL_PERCENT = '100%';
    public readonly NINETY_PERCENT = '90%';
    public readonly EIGHTY_PERCENT = '80%';
    public readonly SEVENTY_FIVE_PERCENT = '75%';
    public readonly SEVENTY_PERCENT = '70%';
    public readonly SIXTY_PERCENT = '60%';
    public readonly FIFTY_PERCENT = '50%';
    public readonly FORTY_PERCENT = '40%';
    public readonly THIRTY_PERCENT = '30%';
    public readonly TWENTY_FIVE_PERCENT = '25%';
    public readonly TWENTY_PERCENT = '20%';
    public readonly FIFTEEN_PERCENT = '15%';
    public readonly THIRTEEN_PERCENT = '13%';
    public readonly TEN_PERCENT = '10%';
    public readonly FIVE_PERCENT = '5%';
    public readonly THREE_PERCENT = '3%';
    public readonly TWO_PERCENT = '2%';
    public readonly ONE_PERCENT = '1%';

    public readonly MARGIN_FIFTY = 50;
    public readonly MARGIN_FORTY = 40;
    public readonly MARGIN_THIRTY = 30;
    public readonly MARGIN_TWENTY = 20;
    public readonly MARGIN_TEN = 10;
    public readonly MARGIN_FIVE = 5;

    public readonly PADDING_TWENTY = 20;
    public readonly PADDING_SIXTEEN = 16;
    public readonly PADDING_FIFTEEN = 15;
    public readonly PADDING_TWELVE = 12;
    public readonly PADDING_TEN = 10;
    public readonly PADDING_EIGHT = 8;
    public readonly PADDING_FIVE = 5;
    public readonly PADDING_TWO = 2;

    public readonly DIALOG_TITLE_FONT_SIZE = 23;
    public readonly DIALOG_CONTENT_FONT_SIZE = 18;

    public readonly INPUT_BORDER_WIDTH = 1;
    public readonly INPUT_BORDER_RADIUS = 20;

    public readonly LOADING_WIDTH = 128;

    public readonly PROGRESS_STROKE_WIDTH = 18;
    public readonly PROGRESS_WIDTH = 72;
    public readonly PROGRESS_TEXT_FONT_SIZE = 17;
    public readonly BLUE_LEVEL = 10;

    public readonly COMMAND_TILE_COL_SPACE = 12;
    public readonly COMMAND_TILE_ROW_SPACE = 8;
    public readonly COMMAND_TILE_NAME_FONT_SIZE = 16;
    public readonly COMMAND_TILE_COMMAND_FONT_SIZE = 13;
    public readonly COMMAND_TILE_LABEL_FONT_SIZE = 11;
    public readonly COMMAND_TILE_PROGRESS_WIDTH = 64;
    public readonly COMMAND_TILE_PROGRESS_STROKE_WIDTH = 13;

    // 设置页的标题字号不在这里：标题只走 `HdsNavDestination` 的 `titleBar`，页面内不再画大标题（设计 §2.6 ⑦ / F3）
    public readonly SETTINGS_PAGE_LABEL_FONT_SIZE = 17;

    public readonly INDEX_SWIPE_BUTTON_SIZE = 40;
    public readonly INDEX_SETUP_FONT_SIZE = 20;
    public readonly INDEX_NO_ENTRY_TITLE_FONT_SIZE = 18;
    public readonly INDEX_NO_ENTRY_SECOND_TITLE_FONT_SIZE = 14;
    public readonly INDEX_LAYOUT_WEIGHT = 1;
    // 主列表两个容器的预建行数（设计 §2.4 / F7）：一屏约 5 行卡片，4 够覆盖一次快速滑动；
    // 再大就逼近「全量预建」（当前数据 13 条），预建失去意义、回收成本反上来
    public readonly LIST_CACHED_COUNT = 4;
    // 底栏几何：三个页签（指令列表 / ASF测试 / 添加指令）由系统均布，胶囊宽度不显式设（设计 §2.4）。
    // 离底距 = 胶囊底边到屏幕底的距离；系统默认贴屏底（0），用户要求「抬高一点」。
    public readonly INDEX_TAB_BAR_BOTTOM_MARGIN = 32;

    // 胶囊高 56vp：mate60pro 节点树实测 182px ÷ 3.25px/vp；底带 getter 的组成项（设计 §2.4）
    public readonly INDEX_TAB_BAR_CAPSULE_HEIGHT = 56;

    // 底栏渐变遮罩高：0 = 不画遮罩带，卡片滚动时从底栏下方连续穿过（需求 U10 / 设计 §2.4）。
    // 系统默认值是「组件高（含底栏高）+ 32vp」，那条带把卡片下缘整块吃掉，用户看到的「突然消失」就是它。
    public readonly INDEX_TAB_BAR_GRADIENT_MASK_HEIGHT = 0;

    // 底栏占的整条底带高度 = 胶囊高 + 离底距；滚动容器的 `contentEndOffset` 读它让出底带（设计 §2.4）。
    // 消费者：`CommandList` 的单列 `List` 与双列 `Grid`、`LiveTestSection` 与 `AddCommandForm` 的 `Scroll`；
    // 增删消费点后按 `grep -rn contentEndOffset` 对数更新这一句。
    // 用 getter 而不是再抄一个数：改离底距时底带自动跟随，不会静静偏掉。
    public get INDEX_TAB_BAR_HEIGHT(): number {
        return this.INDEX_TAB_BAR_CAPSULE_HEIGHT + this.INDEX_TAB_BAR_BOTTOM_MARGIN;
    }

    public readonly EDIT_PAGE_BLANK_COL_SPACE = 20;
    public readonly EDIT_PAGE_OPTION_COL_SPACE = 15;
    public readonly EDIT_PAGE_ROW_SPACE = 10;
    public readonly EDIT_PAGE_LABEL_FONT_SIZE = 18;
    public readonly EDIT_PAGE_CHECK_LABEL_FONT_SIZE = 16;

    public readonly ADD_COMMAND_COL_SPACE = 20;
    public readonly ADD_COMMAND_OPTION_COL_SPACE = 15;
    public readonly ADD_COMMAND_ROW_SPACE = 10;
    public readonly ADD_COMMAND_LABEL_FONT_SIZE = 18;
    public readonly ADD_COMMAND_CHECK_LABEL_FONT_SIZE = 16;

    public readonly MORE_MENU_ITEM_ICON_SIZE = 28;
    // 图标固定盒宽：图标 28 + 4 余量。标题左缘 = 盒宽 + `PADDING_TWELVE`，描述左缘同一算式（需求 U12 / 设计 §2.6 ③）
    public readonly MORE_MENU_ITEM_ICON_BOX_SIZE = 32;
    public readonly MORE_MENU_ITEM_FONT_SIZE = 17;
    public readonly MORE_MENU_ITEM_DESC_FONT_SIZE = 12;

    // 卡片视觉（本批统一）：主列表卡片与设置页分组卡共用同一套卡面常量——
    // 底色走系统键 `sys.color.comp_background_primary`、1px 描边 `sys.color.comp_divider`，
    // 深浅两套由系统成对给，本仓不再各持一份色值（设计 §2.1）。
    public readonly CARD_RADIUS = 16;
    public readonly CARD_BORDER_WIDTH = 1;
    public readonly CARD_PADDING = 16;
    public readonly CARD_SPACE = 12;
    // 双列卡片固定高度：逐行栈 16 + 19 + 6 + 2×17 + 6 + 20 + 16 = 117，三处文字行高按字号推算，
    // 不是设备读数，所以 117 是初值；最终取值以设备读数（同屏卡高两两相等、内容不裁切）定（设计 §2.2 ①）
    public readonly CARD_HEIGHT_DOUBLE = 117;
    // 控件圆角：徽章用。徽章高约 20vp，12 已超过半高，渲染为全圆（设计 §2.1）
    public readonly CONTROL_RADIUS = 12;
    // 双列卡片右下播放钮：直径 36（需求 U3 的上限是 40），钮内字形 16（设计 §2.2 ③）
    public readonly CARD_PLAY_BUTTON_SIZE = 36;
    public readonly CARD_PLAY_ICON_SIZE = 16;
    // 双列运行环的线宽。最终构建实读（mate60pro，3.25px/vp）：外径 118–122px ≈ 37vp、内孔 ≈ 21vp、
    // 线宽 26px = 8.0vp——环体与播放钮同径，中间有孔，不是实心。
    // 单列大环（64 宽、13 粗）仍读 `COMMAND_TILE_PROGRESS_STROKE_WIDTH`，两处的直径不同、线宽也不同
    public readonly CARD_PLAY_PROGRESS_STROKE = 8;
    // 双列运行环的取景框：`Progress` 的环体渲染比取景框小（框 48 时外径 ≈ 37vp），
    // 取 36 的框环就比钮小一圈，所以框取 48、比按钮槽位大。框由 `CompactActionSlot` 的 Stack
    // 居中溢出，环心仍与钮心重合（三帧实测差 ≤1vp）
    public readonly CARD_PLAY_PROGRESS_BOX_SIZE = 48;

    // 页面左右与内边距；设置四页统一（设计 §2.1）
    public readonly PAGE_PADDING = 16;
    // 表单页内容顶距：`ASFSettingsPage` 与添加表单两处（设计 §2.6 ⑦ / F8）。
    // 表单页首元素是标签文字，贴着标题栏读作拥挤；列表三页首元素是卡片、自带内边距，仍读 `PAGE_PADDING`
    public readonly FORM_PAGE_TOP_PADDING = 24;
    // 设置条目行的上下内边距；分组卡不再自带上下内边距，由每行承担（设计 §2.5 ②）
    public readonly ROW_VERTICAL_PADDING = 12;

    public readonly LIVE_TEST_LABEL_FONT_SIZE = 17;

    public readonly FORM_RESULT_CONTENT_FONT_SIZE = 15;
    public readonly FORM_RESULT_LABEL_FONT_SIZE = 10;
    public readonly FORM_RUNNING_LABEL_FONT_SIZE = 13;
    public readonly FORM_LIST_ITEM_BORDER_RADIUS = 13;
    public readonly FORM_LIST_ITEM_HEIGHT = 50;

    // 颜色模式行的右侧控件限高：原生 `Select` 默认高约 40vp，把该行撑得比同组其它行高一截（需求 U13 / 设计 §2.6 ⑥）。
    // 实测不生效：取值 32 后组件仍渲染 40vp（节点树 130px ÷ 3.25），同一事实的读数在 `AppSelect` 的取用点。
    public readonly COLOR_MODE_ROW_SELECT_HEIGHT = 32;
    // 胶囊字号取该行次级文字档（介于标题 17 与描述 12 之间）。
    public readonly COLOR_MODE_ROW_SELECT_FONT_SIZE = 14;
}

export default new StyleConstants();