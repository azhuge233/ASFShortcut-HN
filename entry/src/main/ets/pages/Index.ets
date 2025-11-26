import http from '@ohos.net.http';
import { common } from '@kit.AbilityKit';

import Logger from '../common/utils/Logger';
import { ASF } from '../common/utils/ASF';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { DB } from '../common/utils/DB';
import CommonConstants from '../common/constants/CommonConstants';
import { CommandEntryViewModel } from '../viewmodel/CommandEntryViewModel';
import { CommandListItem } from '../view/components/CommandTile';
import StyleConstants from '../common/constants/StyleConstants';
import CommonUtils from '../common/utils/CommonUtils';

@Entry
@ComponentV2
struct Index {
    private LOG_TAG = "[pages/Index]";

    @Local listViewModel: CommandEntryListViewModel = new CommandEntryListViewModel();

    @Local currentIndex: number = 0;
    @Local showSetupDialog: boolean = false;
    @Local private isProcessing: boolean = false;

    @Local currentAddress: string = '';
    @Local currentASFPassword: string = '';

    @Local testAddress: string = '';
    @Local testPassword: string = '';
    @Local testCommand: string = '';

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;
    private promptAction = this.uiContext.getPromptAction();

    private scrollerForList: ListScroller = new ListScroller();

    private db = DB.getInstance();
    private asf = new ASF();

    pageStack: NavPathStack = new NavPathStack();

    async onPageShow() {
        if(this.pageStack.size() === 0) await this.checkSettingsAndInit();
        this.listViewModel.loadCommandEntries();
    }

    onPageHide(): void {
        this.safeCloseSwipeActions();
    }

    // 发送指令
    async sendCommand(nickname: string, command: string): Promise<void> {
        try {
            const resp = await this.asf.send(command);
            this.isProcessing = false;

            this.handleResponse(nickname, resp);
        } catch (err) {
            Logger.error(this.LOG_TAG, `<sendCommand> 错误, ${(err as Error).message}`);
            CommonUtils.alert(`错误: ${(err as Error).message}`, this.promptAction);
        } finally {
            this.isProcessing = false;
        }
    }

    // 发送测试指令
    async sendTestCommand(address: string, password: string, command: string): Promise<void> {
        try {
            const resp = await this.asf.sendTest(address, password, command);
            this.isProcessing = false;

            this.handleResponse(this.context.resourceManager.getStringSync($r("app.string.LiveTest_Result_Title").id), resp);
        } catch (err) {
            Logger.error(this.LOG_TAG, `<sendTestCommand> 错误, ${(err as Error).message}`);
            CommonUtils.alert(`错误: ${(err as Error).message}`, this.promptAction);
        } finally {
            this.isProcessing = false;
        }
    }

    // 执行指令后，显示结果的对话框
    private resultPopup(commandNickname: string, message: string) {
        this.pageStack.pushPath({
            name: "SelectableDialog",
            param: [commandNickname, message],
            onPop: (popInfo) => {
                CommonUtils.returnFromSubPage(popInfo);
            }
        });
    }

    // 回调方法 onPop 执行完毕时手动 resolve Promise
    // 避免对话框同时弹出
    private inputPopup(type: string): Promise<string> {
        if(type == "Account") return new Promise((resolve) => {
            this.pageStack.pushPath({
                name: "AccInputDialog",
                onPop: (popInfo) => {
                    CommonUtils.returnFromSubPage(popInfo);
                    resolve(popInfo.result as string);
                }
            });
        });
        else if(type == "ID") return new Promise((resolve) => {
            this.pageStack.pushPath({
                name: "IDInputDialog",
                onPop: (popInfo) => {
                    CommonUtils.returnFromSubPage(popInfo);
                    resolve(popInfo.result as string);
                }
            });
        });
        else return new Promise((resolve) => { resolve(""); });
    }

    // 安全关闭左滑菜单
    // 防止列表没有条目时闪退
    private safeCloseSwipeActions(): void {
        try {
            if (this.listViewModel.commandEntries.length > 0) {
                this.scrollerForList.closeAllSwipeActions();
            }
        } catch (err) {
            Logger.debug(this.LOG_TAG, `关闭左滑菜单失败, ${err}`);
        }
    }

    // 从数据库加载设置条目
    private async loadSettings() {
        this.currentAddress = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address);
        this.currentASFPassword = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password);
    }

    // 初始化 ASF 服务
    // 设置服务器地址和 ASF 密码
    private initASF() {
        this.asf.setAddress(this.currentAddress);
        this.asf.setASFPassword(this.currentASFPassword)
    }

    // 检查数据库是否存在设置
    // 并初始化 ASF 的服务器地址和密码
    private async checkSettingsAndInit(): Promise<void> {
        const isComplete = await this.db.areSettingsComplete();
        if (!isComplete) this.showSetupDialog = true;
        else {
            await this.loadSettings();
            this.initASF();
            // Logger.info(this.LOG_TAG, `应用初始化完成, address: ${this.currentAddress}, password: ${this.currentASFPassword}`);
        }
    }

    // 处理 ASF 响应
    private handleResponse(commandNickname: string, resp: http.HttpResponse | undefined) {
        if (resp === undefined) throw new Error(`空响应`);
        try {
            const result: Record<string, string> = JSON.parse(resp.result.toString());

            if (resp.responseCode == 200) {
                Logger.debug(this.LOG_TAG, `${result["Result"]}`)
                this.resultPopup(commandNickname, result["Result"]);
            } else {
                Logger.debug(this.LOG_TAG, `${result["Message"]}`)
                CommonUtils.alert(`${result["Message"]} 响应码: ${resp.responseCode}`, this.promptAction);
            }
        } catch (err) {
            Logger.error(this.LOG_TAG, `<handleResponse> 错误`);
            throw err as Error;
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
            .onClick(() => {
                this.listViewModel.deleteCommandEntry(entry.toCommandEntry());
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
                    param: [this.listViewModel, entry],
                    onPop: (popInfo) => {
                        CommonUtils.returnFromSubPage(popInfo);
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
                .onClick(() => {})

            Column() {
                Progress({ value: 0, total: 100, type: ProgressType.Ring })
                    .width(StyleConstants.PROGRESS_WIDTH)
                    .color(Color.Blue)
                    .style({
                        strokeWidth: StyleConstants.PROGRESS_STROKE_WIDTH,
                        status: ProgressStatus.LOADING
                    })

                Text($r("app.string.Index_processing"))
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
                .onClick(() => {})

            Column() {
                Text($r("app.string.Index_Setup_Alert_Label"))
                    .fontSize(StyleConstants.INDEX_SETUP_FONT_SIZE)
                    .margin(StyleConstants.MARGIN_FIVE)
                Button($r("app.string.Index_Setup_Button_Label"))
                    .margin(StyleConstants.MARGIN_FIVE)
                    .onClick(() => {
                        this.pageStack.pushPath({
                            name: "SettingsPage",
                            onPop: async (popInfo) => {
                                await this.checkSettingsAndInit();
                                CommonUtils.returnFromSubPage(popInfo);
                            }
                        });
                        this.showSetupDialog = false;
                    })
            }
            .width(StyleConstants.FULL_PERCENT)
            .height(StyleConstants.FULL_PERCENT)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {})
        }
        .onClick(() => {})
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Setup stack loaded!");
        })
    }

    // 构建底部导航栏标签
    @Builder
    TabBuilder(index: number, normalIcon: Resource, selectedIcon: Resource, text: string) {
        Column() {
            Image(this.currentIndex === index ? selectedIcon : normalIcon)
                .width(StyleConstants.INDEX_TAB_ICON_SIZE)
                .height(StyleConstants.INDEX_TAB_ICON_SIZE)
                .opacity(this.currentIndex === index ? 1 : 0.6)

            Text(text)
                .fontSize(StyleConstants.INDEX_TAB_LABEL_FONT_SIZE)
                .fontColor(this.currentIndex === index ? $r("app.color.index_tab_label_selected") : $r("app.color.index_tab_label_unselected"))
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.INDEX_TAB_HEIGHT)
        .justifyContent(FlexAlign.Center)
    }

    // 主页
    @Builder
    MainContent() {
        Column() {
            if (this.listViewModel.commandEntries.length === 0) {
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
            } else {
                List({ scroller: this.scrollerForList }) {
                    ForEach(this.listViewModel.commandEntries, (item: CommandEntryViewModel) => {
                        ListItem() {
                            CommandListItem({
                                item: item,
                                onAccountInput: () => this.inputPopup("Account"),
                                onIDInput: () => this.inputPopup("ID"),
                                onSendCommand: (command: string) => this.sendCommand(item.nickname ,command),
                                onProcessingChange: (processing: boolean) => {
                                    this.isProcessing = processing;
                                }
                            })
                        }
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
                            right: StyleConstants.THREE_PERCENT,
                            bottom: StyleConstants.TWO_PERCENT
                        })
                    })
                }
                .padding(StyleConstants.PADDING_EIGHT)
                .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)
            }
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
        .justifyContent(FlexAlign.Center)
    }

    // 测试页
    @Builder
    LiveTestContent() {
        Scroll() {
            Column() {
                // 提示信息
                Column() {
                    Text($r("app.string.LiveTest_Notice_Title"))
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.Red)
                        .margin({ bottom: StyleConstants.MARGIN_TEN })

                    Text($r("app.string.LiveTest_Notice_Content"))
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE - 2)
                        .fontColor(Color.Gray)
                        .textAlign(TextAlign.Start)
                }
                .width(StyleConstants.NINETY_PERCENT)
                .padding(StyleConstants.PADDING_TEN)
                .backgroundColor($r("app.color.index_test_page_notice_background"))
                .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)
                .margin({ bottom: StyleConstants.MARGIN_TEN })

                // 服务器地址输入
                Text($r("app.string.LiveTest_Address_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        left: StyleConstants.FIVE_PERCENT,
                        bottom: StyleConstants.MARGIN_TEN
                    })

                Row() {
                    TextInput({
                        text: this.testAddress,
                        placeholder: $r("app.string.LiveTest_Address_Input_Placeholder")
                    })
                        .layoutWeight(1)
                        .border({
                            width: StyleConstants.INPUT_BORDER_WIDTH,
                            color: Color.Gray
                        })
                        .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)
                        .padding(StyleConstants.PADDING_TEN)
                        .onChange((value: string) => {
                            this.testAddress = value;
                        })

                    Text("/Api/Command")
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE - 2)
                        .margin({ left: StyleConstants.MARGIN_TEN })
                }
                .width(StyleConstants.NINETY_PERCENT)
                .margin({ bottom: StyleConstants.MARGIN_TEN })

                // 密码输入
                Text($r("app.string.LiveTest_Password_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        left: StyleConstants.FIVE_PERCENT,
                        bottom: StyleConstants.MARGIN_TEN
                    })

                TextInput({
                    text: this.testPassword,
                    placeholder: $r("app.string.LiveTest_Password_Input_Placeholder")
                })
                    .type(InputType.Password)
                    .width(StyleConstants.NINETY_PERCENT)
                    .border({
                        width: StyleConstants.INPUT_BORDER_WIDTH,
                        color: Color.Gray
                    })
                    .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)
                    .padding(StyleConstants.PADDING_TEN)
                    .onChange((value: string) => {
                        this.testPassword = value;
                    })
                    .margin({ bottom: StyleConstants.MARGIN_TEN })

                // 指令输入
                Text($r("app.string.LiveTest_Command_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        left: StyleConstants.FIVE_PERCENT,
                        bottom: StyleConstants.MARGIN_TEN
                    })

                TextInput({
                    text: this.testCommand,
                    placeholder: $r("app.string.LiveTest_Command_Input_Placeholder")
                })
                    .width(StyleConstants.NINETY_PERCENT)
                    .border({
                        width: StyleConstants.INPUT_BORDER_WIDTH,
                        color: Color.Gray
                    })
                    .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)
                    .padding(StyleConstants.PADDING_TEN)
                    .onChange((value: string) => {
                        this.testCommand = value;
                    })
                    .margin({ bottom: StyleConstants.MARGIN_FORTY })

                // 发送按钮
                Button($r("app.string.LiveTest_Send_Button_Label"), { type: ButtonType.Capsule })
                    .width(StyleConstants.EIGHTY_PERCENT)
                    .fontColor(Color.White)
                    .enabled(!this.isProcessing &&
                        this.testAddress.trim() !== '' &&
                        this.testPassword.trim() !== '' &&
                        this.testCommand.trim() !== '')
                    .onClick(async () => {
                        this.isProcessing = true;
                        CommonUtils.vibrate();
                        await this.sendTestCommand(this.testAddress, this.testPassword, this.testCommand);
                    })
                    .margin({ bottom: StyleConstants.MARGIN_TWENTY })
            }
            .width(StyleConstants.FULL_PERCENT)
            .height(StyleConstants.FULL_PERCENT)
            .justifyContent(FlexAlign.Start)
            .padding({
                top: StyleConstants.MARGIN_THIRTY,
                bottom: StyleConstants.MARGIN_THIRTY
            })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
    }

    build() {
        Stack() {
            Navigation(this.pageStack) {
                Stack({ alignContent: Alignment.Top }) {
                    Tabs({ barPosition: BarPosition.End }) {
                        TabContent() {
                            if(!this.showSetupDialog) this.MainContent();
                        }
                        .tabBar(this.TabBuilder(
                            0, $r("app.media.doc_plaintext"), $r("app.media.doc_plaintext_fill"), $r("app.string.Index_Tab_Label_Home")
                        ))

                        TabContent() {
                            if(!this.showSetupDialog) this.LiveTestContent();
                        }
                        .tabBar(this.TabBuilder(
                            1, $r("app.media.worldclock"), $r("app.media.worldclock_fill"), $r("app.string.Index_Tab_Label_Test")
                        ))
                    }
                    .onChange((index: number) => {
                        this.currentIndex = index;
                    })
                }
            }
            .menus([
                {
                    value: $r("app.string.Index_Add_Menu_Button_Label"),
                    icon: $r("app.media.plus"),
                    action: () => {
                        this.safeCloseSwipeActions();
                        this.pageStack.pushPath({
                            name: "AddCommand",
                            param: this.listViewModel,
                            onPop: async (popInfo) => {
                                CommonUtils.returnFromSubPage(popInfo);
                            }
                        });
                    }
                },
                {
                    value: $r("app.string.Index_More_Menu_Button_Label"),
                    icon: $r("app.media.dot_grid_2x2"),
                    action: () => {
                        this.safeCloseSwipeActions();
                        this.pageStack.pushPath({
                            name: "MorePage",
                            param: this.listViewModel,
                            onPop: async (popInfo) => {
                                await this.checkSettingsAndInit();
                                CommonUtils.returnFromSubPage(popInfo);
                            }
                        });
                    }
                }
            ])
            .title($r("app.string.Index_Title"))
            .mode(NavigationMode.Auto)
            .height(StyleConstants.FULL_PERCENT)
            .width(StyleConstants.FULL_PERCENT)
            .alignSelf(ItemAlign.Center)
            .onAppear(() => {
                Logger.debug(this.LOG_TAG, "Loaded!");
            })

            if (this.showSetupDialog) {
                this.SetupPopup();
            }

            if (this.isProcessing) {
                this.LoadingContent();
            }
        }
    }
}
