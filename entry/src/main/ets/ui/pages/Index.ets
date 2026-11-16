import { common } from '@kit.AbilityKit';
import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationMenuContentOptions, HdsTabs,
    HdsTabsController, ScrollEffectType } from '@hms.hds.hdsBaseComponent';
import { hdsMaterial, HdsNavigationTitleMode } from '@kit.UIDesignKit';

import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import StyleConstants from '../../common/constants/StyleConstants';
import { AppSettings, ColorMode, ListLayout } from '../../domain/model/AppSettings';
import CommandListViewModel, { CommandOutcome } from '../../viewmodel/CommandListViewModel';
import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';
import { CommandList } from '../components/CommandList';
import { LiveTestSection } from '../components/LiveTestSection';
import { AddCommandForm } from '../components/AddCommandForm';
import { AppButton, AppButtonKind } from '../components/AppButton';
import { AppEmptyState } from '../components/AppEmptyState';
import { AppSearchField } from '../components/AppSearchField';
import { CommandEditViewModel } from '../../viewmodel/CommandEditViewModel';
import PageContext from '../common/PageContext';

@Entry
@ComponentV2
struct Index {
    private LOG_TAG = "[pages/Index]";

    @Local viewModel: CommandListViewModel = new CommandListViewModel();

    // 添加表单的 VM 提在页面级：切页签时表单节点可能重建，草稿在这里不随节点丢（设计 §2.5）。
    // 初值是占位实例（首个 build 前必须有一个合法实例），`aboutToAppear` 里换成绑定主列表 VM 的那一个
    @Local commandEditViewModel: CommandEditViewModel = new CommandEditViewModel(new CommandListViewModel());

    // 搜索框显隐：纯展示态，留页面；关键字与过滤仍在 VM（设计 §2.1）
    @Local isSearchVisible: boolean = false;

    // 排序态：纯展示态，不落盘；退出回原布局由派生值成立（设计 §2.2）
    @Local isSorting: boolean = false;

    @Local appSettings: AppSettings = AppStorageV2.connect(AppSettings, CommonConstants.APP_STORAGE_KEY_APP_SETTINGS,
        () => new AppSettings(ColorMode.FOLLOW_SYSTEM))!;

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;
    private promptAction = this.uiContext.getPromptAction();

    private scrollerForList: ListScroller = new ListScroller();
    private scrollerForGrid: Scroller = new Scroller();
    private tabController: HdsTabsController = new HdsTabsController();

    // 底栏胶囊离底距（见 `StyleConstants.INDEX_TAB_BAR_BOTTOM_MARGIN`）
    private get tabBarBottomMargin(): number {
        return StyleConstants.INDEX_TAB_BAR_BOTTOM_MARGIN;
    }

    // 生效布局：排序态一律单列，退出即回到落盘的布局（设计 §2.2）
    private get effectiveLayout(): ListLayout {
        return this.isSorting ? ListLayout.SINGLE : this.viewModel.listLayout;
    }

    // 标题栏绑定当前生效容器的那一个滚动器，切布局时随 `build` 重算（设计 §2.5）
    private get scrollables(): Array<Scroller> {
        return this.effectiveLayout === ListLayout.DOUBLE ? [this.scrollerForGrid] : [this.scrollerForList];
    }

    // HdsNavigation 新版菜单：三项固定为 布局切换 / 搜索 / 设置（C1）。
    // 第一项的图标与动作随态走：排序态读「完成」，否则按当前布局读对应网格图标（设计 §2.3）
    private get menus(): HdsNavigationMenuContentOptions {
        const layoutIcon: Resource = this.isSorting ? $r("sys.symbol.checkmark") :
            (this.viewModel.listLayout === ListLayout.SINGLE ? $r("sys.symbol.rectangle_grid_1x2") :
                $r("sys.symbol.square_grid_2x2"));
        const layoutLabel: Resource = this.isSorting ? $r("app.string.Index_Done_Menu_Button_Label") :
            (this.viewModel.listLayout === ListLayout.SINGLE ? $r("app.string.Index_Layout_Double_Menu_Button_Label") :
                $r("app.string.Index_Layout_Single_Menu_Button_Label"));
        const layoutAction: () => void = () => {
            if (this.isSorting) {
                this.isSorting = false;
                return;
            }
            this.safeCloseSwipeActions();
            this.viewModel.toggleLayout();
        };

        return {
            value: [
                {
                    content: {
                        label: layoutLabel,
                        icon: layoutIcon,
                        action: layoutAction
                    }
                },
                {
                    content: {
                        label: $r("app.string.Index_Search_Menu_Button_Label"),
                        icon: this.isSearchVisible ? $r("sys.symbol.xmark") : $r("sys.symbol.magnifyingglass"),
                        action: () => {
                            if (this.isSearchVisible) this.collapseSearch();
                            else this.isSearchVisible = true;
                        }
                    }
                },
                {
                    content: {
                        label: $r("app.string.Index_More_Menu_Button_Label"),
                        icon: $r("sys.symbol.gearshape"),
                        action: () => {
                            this.safeCloseSwipeActions();
                            this.pageStack.pushPath({
                                name: "MorePage",
                                param: this.viewModel,
                                onPop: async (popInfo) => {
                                    await this.viewModel.init();
                                    PageContext.returnFromSubPage(popInfo);
                                }
                            });
                        }
                    }
                }
            ]
        };
    }

    pageStack: NavPathStack = new NavPathStack();

    // 长按快捷方式要去的页面：记下上次已消费的值，从子页/后台回来时不重复跳
    private consumedShortcutPath: string = '';

    aboutToAppear(): void {
        // 添加表单的 VM 绑到本页的主列表 VM：新增要落库并刷新列表与卡片，走的就是它（设计 §2.5）
        this.commandEditViewModel = new CommandEditViewModel(this.viewModel);

        // 布局读的是 `AppStorageV2` 的全应用同一份设置：先接上，`init()` 里的 `loadLayout()` 才有落点
        this.viewModel.attachSettings(this.appSettings);

        // 拖拽落库失败：VM 内部已按数据库顺序回滚并重刷列表，页面只提示，不再重复读库
        this.viewModel.onMoveFailed = () => {
            Logger.warn(this.LOG_TAG, `拖拽顺序未保存，列表已回滚`);
            PageContext.alert($r("app.string.Index_Reorder_Failed"), this.promptAction);
        };
    }

    async onPageShow() {
        // 首次进入要先把设置与发送器准备好；从子页回来只重读列表
        if (this.pageStack.size() === 0) await this.viewModel.init();
        else await this.viewModel.loadEntries();

        // 每次前台回来都读一次窗口通道（设计 §2.6，通道只读不写）：
        // 应用已在运行时再次长按快捷方式，`onNewWant` 会重写同一个键，读得到新值才跳；
        // 与上次已消费的值相同则不跳，避免从子页返回时重复跳转
        const shortcutPath: string =
            PageContext.readWindowParam(this.uiContext, CommonConstants.APP_STORAGE_KEY_SHORTCUT_PATH);
        if (shortcutPath !== '' && shortcutPath !== this.consumedShortcutPath) {
            this.consumedShortcutPath = shortcutPath;

            Logger.debug(this.LOG_TAG, `检测到长按快捷方式页面`);
            await this.goToSpecifyPage(shortcutPath);
        }
    }

    onPageHide(): void {
        this.safeCloseSwipeActions();
    }

    // 快捷方式跳转判断
    private async goToSpecifyPage(path: string): Promise<void> {
        // 应用未初始化，不跳转
        if (this.viewModel.showSetup) {
            PageContext.alert($r("app.string.App_Shortcut_Add_Shortcut_Not_Init_Alert"), this.promptAction);
            Logger.debug(this.LOG_TAG, `应用未完成初始化，停止跳转`);
            return;
        }

        // 如果应用内已经进入其他页面，返回到主页面
        if (this.pageStack.size() > 0) this.pageStack.clear();

        try {
            Logger.debug(this.LOG_TAG, `跳转至页面 ${path}`);
            this.pageStack.pushPath({
                name: path,
                param: this.viewModel,
                onPop: async (popInfo) => {
                    PageContext.returnFromSubPage(popInfo);
                }
            });
        } catch (err) {
            Logger.error(this.LOG_TAG, `${path} 页面跳转失败, ${err}`);
        }
    }

    // 发送指令：结果呈现留在页面，VM 只给 kind 与文本（设计 §2.4.2）
    private async sendCommand(nickname: string, command: string): Promise<void> {
        const outcome: CommandOutcome = await this.viewModel.execute(nickname, command);
        this.presentOutcome(nickname, outcome);
    }

    // 发送测试指令：振动与结果标题留在页面
    private async sendTestCommand(): Promise<void> {
        PageContext.vibrate(CommonConstants.VIBRATE_EFFECT_ID_HARD);

        const outcome: CommandOutcome = await this.viewModel.executeTest(this.viewModel.testAddress,
            this.viewModel.testPassword, this.viewModel.testCommand);

        const testTitle: string = this.context.resourceManager
            .getStringSync($r("app.string.LiveTest_Result_Title").id);
        this.presentOutcome(testTitle, outcome);
    }

    // 按呈现意图选控件：结果弹对话框、其他响应码提示、失败按错误提示
    private presentOutcome(nickname: string, outcome: CommandOutcome): void {
        if (outcome.kind === 'result') this.resultPopup(nickname, outcome.text);
        else if (outcome.kind === 'notice') PageContext.alert(outcome.text, this.promptAction);
        else PageContext.alert(`错误: ${outcome.text}`, this.promptAction);
    }

    // 执行指令后，显示结果的对话框
    private resultPopup(commandNickname: string, message: string) {
        this.pageStack.pushPath({
            name: "SelectableDialog",
            param: [commandNickname, message],
            onPop: (popInfo) => {
                PageContext.returnFromSubPage(popInfo);
            }
        });
    }

    // 回调方法 onPop 执行完毕时手动 resolve Promise
    // 避免对话框同时弹出
    private inputPopup(type: string): Promise<string> {
        if (type == "Account") return new Promise((resolve) => {
            this.pageStack.pushPath({
                name: "AccountInputDialog",
                onPop: (popInfo) => {
                    PageContext.returnFromSubPage(popInfo);
                    resolve(popInfo.result as string);
                }
            });
        }); else if (type == "ID") return new Promise((resolve) => {
            this.pageStack.pushPath({
                name: "IDInputDialog",
                onPop: (popInfo) => {
                    PageContext.returnFromSubPage(popInfo);
                    resolve(popInfo.result as string);
                }
            });
        }); else return new Promise((resolve) => {
            resolve("");
        });
    }

    // 搜索收起：两个入口（标题栏图标 / 搜索框取消按钮）都只调它，关键字一并清空（A3 / A4）
    private collapseSearch(): void {
        this.isSearchVisible = false;
        this.viewModel.setKeyword('');
    }

    // 安全关闭左滑菜单
    // 防止列表没有条目时闪退；双列没有左滑能力，不作无意义的调用（设计 §2.5）
    private safeCloseSwipeActions(): void {
        try {
            if (this.effectiveLayout === ListLayout.SINGLE && this.viewModel.entries.length > 0) {
                this.scrollerForList.closeAllSwipeActions();
            }
        } catch (err) {
            Logger.debug(this.LOG_TAG, `关闭左滑菜单失败, ${err}`);
        }
    }

    // 打开编辑页：左滑按钮与双列长按菜单都调它
    private openEditPage(entry: CommandEntryViewModel): void {
        this.safeCloseSwipeActions();
        this.pageStack.pushPath({
            name: "EditPage",
            param: [this.viewModel, entry],
            onPop: (popInfo) => {
                PageContext.returnFromSubPage(popInfo);
            }
        });
    }

    // 删除确认与落库：两个入口（单列左滑 / 双列长按菜单）走同一条确认路径
    private async confirmDelete(entry: CommandEntryViewModel): Promise<void> {
        try {
            const result = await this.promptAction.showDialog({
                title: $r("app.string.Index_Deletion_Confirm_Title"),
                message: $r("app.string.Index_Deletion_Confirm_Message", entry.nickname),
                buttons: [
                    {
                        text: $r("app.string.Index_Deletion_Confirm"),
                        color: $r("sys.color.warning")
                    },
                    {
                        text: $r("app.string.Index_Deletion_Cancel"),
                        color: $r("sys.color.font_primary")
                    }
                ]
            });

            if (result.index === 0) {
                const deleteResult = await this.viewModel.deleteEntry(entry.toCommandEntry());
                if (!deleteResult.ok) {
                    PageContext.alert(deleteResult.unbindFailed ?
                        $r("app.string.Index_Deletion_Failed_Unbind") : $r("app.string.Index_Deletion_Failed"),
                        this.promptAction);
                }
            } else Logger.warn(this.LOG_TAG, `取消删除`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `删除确认框弹出失败`);
        }
    }

    // 进排序态：双列长按菜单第三项；布局不改写，退出由 `effectiveLayout` 回到原布局（C7）
    private enterSorting(): void {
        this.isSorting = true;
    }

    // ASF 发送指令时显示
    // 阻止用户操作
    @Builder
    LoadingContent() {
        Stack() {
            Column()
                .width(StyleConstants.FULL_PERCENT)
                .height(StyleConstants.FULL_PERCENT)
                .backgroundColor($r("app.color.transparent"))
                .blur(StyleConstants.BLUE_LEVEL)
                .onClick(() => {
                })

            Column() {
                Progress({ value: 0, total: 100, type: ProgressType.Ring })
                    .width(StyleConstants.PROGRESS_WIDTH)
                    .color(Color.Blue)
                    .style({
                        strokeWidth: StyleConstants.PROGRESS_STROKE_WIDTH,
                        status: ProgressStatus.LOADING
                    })

                Text($r("app.string.Index_Processing"))
                    .margin({ top: StyleConstants.MARGIN_TWENTY })
                    .fontSize(StyleConstants.PROGRESS_TEXT_FONT_SIZE)
            }
            .width(StyleConstants.FULL_PERCENT)
            .height(StyleConstants.FULL_PERCENT)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
            })
        }
        .onClick(() => {
        })
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Blocking stack loaded!");
        })
    }

    // 检测到数据库未设置 ASF 相关条目时显示
    // 提示前往设置页面
    @Builder
    SetupPopup() {
        Stack() {
            Column()
                .width(StyleConstants.FULL_PERCENT)
                .height(StyleConstants.FULL_PERCENT)
                .backgroundColor($r("app.color.transparent"))
                .blur(StyleConstants.BLUE_LEVEL)
                .onClick(() => {
                })

            Column() {
                Text($r("app.string.Index_Setup_Alert_Label"))
                    .fontSize(StyleConstants.INDEX_SETUP_FONT_SIZE)
                    .margin(StyleConstants.MARGIN_FIVE)
                // 盘上这一句是 `Button(label)`：不设 type、不设宽度、不设字色。
                // 主态三样都带（胶囊 + 满宽 + 白字），套上去会把本按钮从圆角矩形改成胶囊并拉满整宽；
                // 按「用契约里已有的参数把盘上原形表达出来、不改画面」取次态 + `stretch: false`。
                // 设计 §3 第 25 行写的是 `kind: Primary` 并判定「改后相同」——那一行把主态当成了 `Button(label)` 的原样，
                // 与本机 API 23 起「`Button(label)` 默认 `ROUNDED_RECTANGLE`」不符，已在 §5 报明
                AppButton({
                    label: $r("app.string.Index_Setup_Button_Label"),
                    kind: AppButtonKind.Secondary,
                    stretch: false,
                    onTap: () => {
                        this.pageStack.pushPath({
                            name: "ASFSettingsPage",
                            onPop: async (popInfo) => {
                                await this.viewModel.init();
                                PageContext.returnFromSubPage(popInfo);
                            }
                        });
                        this.viewModel.showSetup = false;
                    }
                })
                    .margin(StyleConstants.MARGIN_FIVE)
            }
            .width(StyleConstants.FULL_PERCENT)
            .height(StyleConstants.FULL_PERCENT)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
            })
        }
        .onClick(() => {
        })
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Setup stack loaded!");
        })
    }

    // 加载失败：显示原因入口并可重试，不把读失败显示成「没有指令」（X3）；点击只挂在标题文字上（AppEmptyState）
    @Builder
    LoadFailedContent() {
        AppEmptyState({
            title: $r("app.string.Index_Load_Failed_Retry"),
            onTap: async () => {
                Logger.debug(this.LOG_TAG, `点击重试加载, 原因: ${this.viewModel.loadError}`);
                await this.viewModel.retryLoad();
            }
        })
    }

    // 搜索控件：不占标题栏、不新增浮层（设计 §2.4.3、§8）
    // 控件六项收在 `AppSearchField` 内；取消按钮仍走 `Search.searchButton`（SDK：「Clicking the search button
    // triggers both onSubmit and onClick callbacks.」），所以仍是「同时触发 onSubmit 与 onClick」
    @Builder
    SearchBar() {
        AppSearchField({
            value: this.viewModel.keyword,
            onChange: (value: string) => {
                this.viewModel.setKeyword(value);
            },
            onCollapse: () => {
                this.collapseSearch();
            }
        })
    }

    // 主页
    @Builder
    MainContent() {
        Column() {
            if (this.viewModel.loadError !== '') {
                this.LoadFailedContent();
            } else if (this.viewModel.isEmpty()) {
                AppEmptyState({
                    title: $r("app.string.Index_No_Commands_Label"),
                    subtitle: $r("app.string.Index_Create_First_Command_Label")
                })
            } else if (this.viewModel.isNoMatch()) {
                Column() {
                    if (this.isSearchVisible) {
                        this.SearchBar();
                    }

                    Column() {
                        AppEmptyState({ title: $r("app.string.Index_Search_No_Result") })
                    }
                    .width(StyleConstants.FULL_PERCENT)
                    .height(StyleConstants.FULL_PERCENT)
                }
                .width(StyleConstants.FULL_PERCENT)
                .height(StyleConstants.FULL_PERCENT)
            } else {
                Column() {
                    if (this.isSearchVisible) {
                        this.SearchBar();
                    }

                    // 列表容器搬进 `CommandList`（设计 §2.5）：本页只传参、接收事件
                    CommandList({
                        entries: this.viewModel.entries,
                        layout: this.effectiveLayout,
                        runningIDs: this.viewModel.runningIDs,
                        listScroller: this.scrollerForList,
                        gridScroller: this.scrollerForGrid,
                        onAccountInput: () => this.inputPopup("Account"),
                        onIDInput: () => this.inputPopup("ID"),
                        onSendCommand: async (entry: CommandEntryViewModel, command: string) => {
                            await this.sendCommand(entry.nickname, command);
                        },
                        onRunningStateChange: (entry: CommandEntryViewModel, isRunning: boolean) => {
                            this.viewModel.setRunning(entry.id, isRunning);
                        },
                        onEdit: (entry: CommandEntryViewModel) => {
                            this.openEditPage(entry);
                        },
                        onDelete: (entry: CommandEntryViewModel) => {
                            this.confirmDelete(entry);
                        },
                        onSortRequest: () => {
                            this.enterSorting();
                        },
                        onMove: (from: number, to: number) => this.viewModel.move(from, to)
                    })
                }
                .width(StyleConstants.FULL_PERCENT)
                .height(StyleConstants.FULL_PERCENT)
            }
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
        .justifyContent(FlexAlign.Center)
    }

    build() {
        Stack() {
            HdsNavigation(this.pageStack) {
                Stack({ alignContent: Alignment.Top }) {
                    HdsTabs({ controller: this.tabController }) {
                        TabContent() {
                            if (!this.viewModel.showSetup) this.MainContent();
                        }
                        .tabBar(new BottomTabBarStyle({
                            normal: new SymbolGlyphModifier($r("sys.symbol.doc_plaintext_fill")),
                            selected: new SymbolGlyphModifier($r("sys.symbol.doc_plaintext_fill"))
                        }, $r("app.string.Index_Tab_Label_Home")))

                        // 中间的页签（序 1）：添加指令常驻（设计 §2.5 / F9）。
                        // 添加是主操作，占中间位；表单节点可能被重建，草稿在页面级 VM 里
                        TabContent() {
                            if (!this.viewModel.showSetup) {
                                AddCommandForm({
                                    viewModel: this.commandEditViewModel,
                                    // 保存成功后切回「指令列表」（序 0）：常驻页签下停在空表单上是坏形态（需求 U5）
                                    onSaved: () => {
                                        this.tabController.changeIndex(0);
                                    }
                                })
                            }
                        }
                        .tabBar(new BottomTabBarStyle({
                            normal: new SymbolGlyphModifier($r("sys.symbol.plus")),
                            selected: new SymbolGlyphModifier($r("sys.symbol.plus"))
                        }, $r("app.string.Index_Tab_Label_Add")))

                        // 最后一个页签（序 2）：ASF 测试（设计 §2.4 / F9）
                        TabContent() {
                            if (!this.viewModel.showSetup) {
                                LiveTestSection({
                                    viewModel: this.viewModel,
                                    onSend: async () => {
                                        await this.sendTestCommand();
                                    }
                                })
                            }
                        }
                        .tabBar(new BottomTabBarStyle({
                            normal: new SymbolGlyphModifier($r("sys.symbol.worldclock_fill")),
                            selected: new SymbolGlyphModifier($r("sys.symbol.worldclock_fill"))
                        }, $r("app.string.Index_Tab_Label_Test")))
                    }
                    // 页面底与卡面分层（需求 U11）：页面走 `background_secondary`，卡面仍是 `comp_background_primary`
                    .backgroundColor($r("sys.color.background_secondary"))
                    .barPosition(BarPosition.End)
                    .barOverlap(true)
                    // 悬浮胶囊 + 沉浸材质，三个页签由系统均布（设计 §2.4）。宽度不显式设。
                    .barFloatingStyle({
                        barBottomMargin: this.tabBarBottomMargin,
                        // 遮罩高显式归零：系统默认值是「组件高 + 32vp」，那条带把卡片下缘整块吃掉（需求 U10）
                        gradientMask: {
                            maskHeight: StyleConstants.INDEX_TAB_BAR_GRADIENT_MASK_HEIGHT
                        },
                        systemMaterialEffect: {
                            materialType: hdsMaterial.MaterialType.ADAPTIVE,
                            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                        }
                    })
                    .onChange((index: number) => {
                        this.viewModel.setCurrentTab(index);
                    })
                }
            }
            .titleBar({
                content: {
                    title: {
                        mainTitle: $r("app.string.Index_Title"),
                    },
                    menu: this.menus,
                },
                style: {
                    scrollEffectOpts: {
                        // 设置滚动特效
                        enableScrollEffect: true,
                        scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
                    },
                    systemMaterialEffect: {
                        // 设置沉浸光感
                        materialType: hdsMaterial.MaterialType.ADAPTIVE,
                        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                    },
                },
                //avoidLayoutSafeArea: false,
                enableComponentSafeArea: true // 启用标题栏占位
            })
            .bindToScrollable(this.scrollables)
            // 标题固定大标题（F10）：不设时走默认 FREE，标题随滚动自动收放——用户实测过「缩下去回不到顶」
            // 与「样式回来了位置没回来」，那是两套状态机各走一半。固定 FULL 直接根除这类不同步；
            // 代价是 `ScrollEffectType.GRADIENT_BLUR` 不再触发（它本就服务于标题收缩时内容透出），这是预期结果。
            .titleMode(HdsNavigationTitleMode.FULL)
            .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
            .height(StyleConstants.FULL_PERCENT)
            .width(StyleConstants.FULL_PERCENT)
            .alignSelf(ItemAlign.Center)
            // 页面底与卡面分层（需求 U11），与 HdsTabs 自身同一个键
            .backgroundColor($r("sys.color.background_secondary"))
            .onAppear(() => {
                Logger.debug(this.LOG_TAG, "Loaded!");
            })

            if (this.viewModel.showSetup) {
                this.SetupPopup();
            }

            if (this.viewModel.isProcessing) {
                this.LoadingContent();
            }
        }
    }
}
