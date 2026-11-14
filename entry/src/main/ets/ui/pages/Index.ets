import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { HdsNavigation, HdsNavigationMenuContentOptions, HdsTabs,
    HdsTabsController, ScrollEffectType } from '@hms.hds.hdsBaseComponent';
import { hdsMaterial } from '@kit.UIDesignKit';

import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import CommandListViewModel, { CommandOutcome } from '../../viewmodel/CommandListViewModel';
import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';
import { CommandTile } from '../components/CommandTile';
import { LiveTestSection } from '../components/LiveTestSection';
import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';

@Entry
@ComponentV2
struct Index {
    private LOG_TAG = "[pages/Index]";

    @Local viewModel: CommandListViewModel = new CommandListViewModel();

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;
    private promptAction = this.uiContext.getPromptAction();

    private scrollerForList: ListScroller = new ListScroller();
    private tabController: HdsTabsController = new HdsTabsController();

    // HdsNavigation 新版菜单
    private menus: HdsNavigationMenuContentOptions = {
        value: [
            {
                content: {
                    label: $r("app.string.Index_Add_Menu_Button_Label"),
                    icon: $r("sys.symbol.plus"),
                    action: () => {
                        this.safeCloseSwipeActions();
                        this.pageStack.pushPath({
                            name: "AddCommand",
                            param: this.viewModel,
                            onPop: async (popInfo) => {
                                PageContext.returnFromSubPage(popInfo);
                            }
                        });
                    }
                }
            },
            {
                content: {
                    label: $r("app.string.Index_More_Menu_Button_Label"),
                    icon: $r("sys.symbol.dot_grid_2x2"),
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

    pageStack: NavPathStack = new NavPathStack();

    aboutToAppear(): void {
        // 拖拽落库失败：VM 内部已按数据库顺序回滚，页面再刷一次并 toast 提示（设计 §2.4.5）
        this.viewModel.onMoveFailed = () => {
            Logger.warn(this.LOG_TAG, `拖拽顺序未保存，列表已回滚`);
            PageContext.alert($r("app.string.Index_Reorder_Failed"), this.promptAction);
            this.viewModel.loadEntries();
        };
    }

    async onPageShow() {
        // 首次进入要先把设置与发送器准备好；从子页回来只重读列表
        if (this.pageStack.size() === 0) await this.viewModel.init();
        else await this.viewModel.loadEntries();

        if (AppStorage.has(CommonConstants.APP_STORAGE_KEY_SHORTCUT_PATH)) {
            Logger.debug(this.LOG_TAG, `检测到长按快捷方式页面`);

            const path: string | undefined = AppStorage.get(CommonConstants.APP_STORAGE_KEY_SHORTCUT_PATH);
            if (path) {
                await this.goToSpecifyPage(path);
                AppStorage.delete(CommonConstants.APP_STORAGE_KEY_SHORTCUT_PATH);
            }
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

    // 安全关闭左滑菜单
    // 防止列表没有条目时闪退
    private safeCloseSwipeActions(): void {
        try {
            if (this.viewModel.entries.length > 0) {
                this.scrollerForList.closeAllSwipeActions();
            }
        } catch (err) {
            Logger.debug(this.LOG_TAG, `关闭左滑菜单失败, ${err}`);
        }
    }

    // 删除按钮
    @Builder
    DeleteButton(entry: CommandEntryViewModel) {
        Row() {
            Button() {
                Image($r("app.media.trash"))
                    .objectFit(ImageFit.Cover)
                    .width(StyleConstants.SIXTY_PERCENT)
                    .height(StyleConstants.SIXTY_PERCENT)
            }
            .backgroundColor($r("app.color.delete_button_color"))
            .type(ButtonType.Circle)
            .width(StyleConstants.INDEX_SWIPE_BUTTON_SIZE)
            .height(StyleConstants.INDEX_SWIPE_BUTTON_SIZE)
            .onClick(async () => {
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
            })
        }
        .margin({
            left: StyleConstants.THREE_PERCENT
        })
    }

    // 编辑按钮
    @Builder
    EditButton(entry: CommandEntryViewModel) {
        Row() {
            Button() {
                Image($r("app.media.square_and_pencil"))
                    .objectFit(ImageFit.Cover)
                    .width(StyleConstants.SIXTY_PERCENT)
                    .height(StyleConstants.SIXTY_PERCENT)
            }
            .backgroundColor($r("app.color.edit_button_color"))
            .type(ButtonType.Circle)
            .width(StyleConstants.INDEX_SWIPE_BUTTON_SIZE)
            .height(StyleConstants.INDEX_SWIPE_BUTTON_SIZE)
            .onClick(() => {
                this.safeCloseSwipeActions();
                this.pageStack.pushPath({
                    name: "EditPage",
                    param: [this.viewModel, entry],
                    onPop: (popInfo) => {
                        PageContext.returnFromSubPage(popInfo);
                    }
                });
            })
        }
        .margin({
            left: StyleConstants.THREE_PERCENT
        })
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
                Button($r("app.string.Index_Setup_Button_Label"))
                    .margin(StyleConstants.MARGIN_FIVE)
                    .onClick(() => {
                        this.pageStack.pushPath({
                            name: "ASFSettingsPage",
                            onPop: async (popInfo) => {
                                await this.viewModel.init();
                                PageContext.returnFromSubPage(popInfo);
                            }
                        });
                        this.viewModel.showSetup = false;
                    })
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

    // 加载失败：显示原因入口并可重试，不把读失败显示成「没有指令」（X3）
    @Builder
    LoadFailedContent() {
        Column() {
            Text($r("app.string.Index_Load_Failed_Retry"))
                .fontSize(StyleConstants.INDEX_NO_ENTRY_TITLE_FONT_SIZE)
                .fontColor(Color.Gray)
                .textAlign(TextAlign.Center)
                .onClick(async () => {
                    Logger.debug(this.LOG_TAG, `点击重试加载, 原因: ${this.viewModel.loadError}`);
                    await this.viewModel.retryLoad();
                })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
        .width(StyleConstants.FULL_PERCENT)
    }

    // 搜索控件：不占标题栏、不新增浮层（设计 §2.4.3、§8）
    @Builder
    SearchBar() {
        Search({
            value: this.viewModel.keyword,
            placeholder: $r("app.string.Index_Search_Placeholder")
        })
            .width(StyleConstants.NINETY_PERCENT)
            .margin({ bottom: StyleConstants.MARGIN_FIVE })
            .onChange((value: string) => {
                this.viewModel.setKeyword(value);
            })
    }

    // 主页
    @Builder
    MainContent() {
        Column() {
            if (this.viewModel.loadError !== '') {
                this.LoadFailedContent();
            } else if (this.viewModel.isEmpty()) {
                Column() {
                    Text($r("app.string.Index_No_Commands_Label"))
                        .fontSize(StyleConstants.INDEX_NO_ENTRY_TITLE_FONT_SIZE)
                        .fontColor(Color.Gray)
                    Text($r("app.string.Index_Create_First_Command_Label"))
                        .fontSize(StyleConstants.INDEX_NO_ENTRY_SECOND_TITLE_FONT_SIZE)
                        .fontColor(Color.Gray)
                        .margin({ top: StyleConstants.MARGIN_TEN })
                }
                .justifyContent(FlexAlign.Center)
                .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
                .width(StyleConstants.FULL_PERCENT)
            } else if (this.viewModel.isNoMatch()) {
                Column() {
                    this.SearchBar();

                    Column() {
                        Text($r("app.string.Index_Search_No_Result"))
                            .fontSize(StyleConstants.INDEX_NO_ENTRY_TITLE_FONT_SIZE)
                            .fontColor(Color.Gray)
                    }
                    .justifyContent(FlexAlign.Center)
                    .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
                    .width(StyleConstants.FULL_PERCENT)
                }
                .width(StyleConstants.FULL_PERCENT)
                .height(StyleConstants.FULL_PERCENT)
            } else {
                Column() {
                    this.SearchBar();

                    List({ scroller: this.scrollerForList }) {
                        ForEach(this.viewModel.entries, (item: CommandEntryViewModel) => {
                            ListItem() {
                                CommandTile({
                                    item: item,
                                    onAccountInput: () => this.inputPopup("Account"),
                                    onIDInput: () => this.inputPopup("ID"),
                                    onSendCommand: (command: string) => this.sendCommand(item.nickname, command),
                                    onRunningStateChange: (isRunning: boolean) => {
                                        this.viewModel.setRunning(item.id, isRunning);
                                    }
                                })
                            }
                            .enabled(!this.viewModel.runningIDs.has(item.id))
                            .swipeAction({
                                end: {
                                    builder: () => {
                                        this.EditButton(item);
                                        this.DeleteButton(item);
                                    }
                                }
                            })
                            .margin({
                                top: StyleConstants.TWO_PERCENT,
                                left: StyleConstants.ONE_PERCENT,
                                right: StyleConstants.ONE_PERCENT,
                                bottom: StyleConstants.TWO_PERCENT
                            })
                        }, (item: CommandEntryViewModel) => item.id.toString())
                            .onMove((from: number, to: number) => {
                                // 同步返回、失败按 DB 顺序回滚：VM 落库失败时调 onMoveFailed
                                return this.viewModel.move(from, to);
                            }, {
                                onLongPress: () => {
                                    PageContext.vibrate(CommonConstants.VIBRATE_EFFECT_ID_SOFT);
                                }
                            })
                    }
                    .padding(StyleConstants.PADDING_EIGHT)
                    .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
                    .height(StyleConstants.FULL_PERCENT)
                    .width(StyleConstants.FULL_PERCENT)
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
                    .backgroundColor($r("sys.color.background_primary"))
                    .barPosition(BarPosition.End)
                    .barOverlap(true)
                    .barFloatingStyle({
                        barBottomMargin: StyleConstants.INDEX_TAB_BAR_MARGIN,
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
            .bindToScrollable([this.scrollerForList])
            .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
            .height(StyleConstants.FULL_PERCENT)
            .width(StyleConstants.FULL_PERCENT)
            .alignSelf(ItemAlign.Center)
            .backgroundColor($r("sys.color.background_primary"))
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
