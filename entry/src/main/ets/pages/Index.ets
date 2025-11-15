import { promptAction } from '@kit.ArkUI';
import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';

import Logger from '../common/utils/Logger';
import { ASF } from '../common/utils/ASF';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { DB } from '../common/utils/DB';
import CommonConstants from '../common/constants/CommonConstants';
import { CommandEntryViewModel } from '../viewmodel/CommandEntryViewModel';
import { CommandListItem } from '../view/components/CommandTile';

@Entry
@ComponentV2
struct Index {
    private LOG_TAG = "[pages/Index]";

    @Local listViewModel: CommandEntryListViewModel = new CommandEntryListViewModel();

    @Local showSetupDialog: boolean = false;
    @Local private isProcessing: boolean = false;

    @Local currentAddress: string = '';
    @Local currentASFPassword: string = '';

    private uiContext = this.getUIContext();
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
        this.scrollerForList.closeAllSwipeActions();
    }

    alert(message: string) {
        if(deviceInfo.sdkApiVersion <= 17) {
            try {
                promptAction.showToast({
                    message: message
                });
            } catch (err) {
                Logger.error(this.LOG_TAG, `<alert API <= 17> error: ${err}`);
            }
        } else {
            this.promptAction.openToast({
                message: message
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `<alert API > 17> error: ${err}`);
            });
        }
    }

    // 执行指令后，显示结果的对话框
    private resultPopup(message: string) {
        this.pageStack.pushPath({
            name: "SelectableDialog",
            param: message,
            onPop: (popInfo) => {
                this.returnFromSubPage(popInfo);
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
                    this.returnFromSubPage(popInfo);
                    resolve(popInfo.result as string);
                }
            });
        });
        else if(type == "ID") return new Promise((resolve) => {
            this.pageStack.pushPath({
                name: "IDInputDialog",
                onPop: (popInfo) => {
                    this.returnFromSubPage(popInfo);
                    resolve(popInfo.result as string);
                }
            });
        });
        else return new Promise((resolve) => { resolve(""); });
    }

    // 安全关闭左滑菜单
    // 防止列表没有条目时闪退、报错
    private safeCloseSwipeActions(): void {
        try {
            if (this.listViewModel.commandEntries.length > 0) {
                this.scrollerForList.closeAllSwipeActions();
            }
        } catch (err) {
            Logger.debug(this.LOG_TAG, `Safe close swipe actions failed, ${err}`);
        }
    }

    // 检查数据库是否存在设置
    // 并初始化 ASF 的服务器地址和密码
    async checkSettingsAndInit(): Promise<void> {
        const isComplete = await this.db.areSettingsComplete();
        if (!isComplete) this.showSetupDialog = true;
        else {
            await this.loadSettings();
            this.initASF();
            // Logger.info(this.LOG_TAG, `应用初始化完成, address: ${this.currentAddress}, password: ${this.currentASFPassword}`);
        }
    }

    // 从数据库加载设置条目
    async loadSettings() {
        this.currentAddress = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address);
        this.currentASFPassword = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password);
    }

    // 初始化 ASF 服务
    initASF() {
        this.asf.setAddress(this.currentAddress);
        this.asf.setASFPassword(this.currentASFPassword)
    }

    // 删除数据库内 ASF 设置条目
    // 重置设置状态
    async resetSettings(): Promise<void> {
        await this.db.clearTableSettings();
        this.showSetupDialog = true;
    }

    // 从 NavDestination 由 pop() 返回时
    // 显示回调 popInfo
    async returnFromSubPage(popInfo: PopInfo): Promise<void> {
        Logger.debug(this.LOG_TAG,
            `Returned from page [${popInfo.info.name}], result: ${JSON.stringify(popInfo.result)}`);
    }

    // 发送指令
    async sendCommand(command: string): Promise<void> {
        try {
            const resp = await this.asf?.send(command);
            this.isProcessing = false;

            if (resp.responseCode == 200) {
                const result: Record<string, string> = JSON.parse(resp.result.toString());
                Logger.debug(this.LOG_TAG, `${result["Result"]}`)
                this.resultPopup(result["Result"]);
            } else {
                const result: Record<string, string> = JSON.parse(resp.result.toString());
                this.alert(`${result["Message"]} Code: ${resp.responseCode}`);
            }
        } catch (err) {
            Logger.error(this.LOG_TAG, `<sendCommand> error: ${err}`)
        } finally {
            this.isProcessing = false;
        }
    }

    // 删除按钮
    @Builder
    DeleteButton(entry: CommandEntryViewModel) {
        Row() {
            Button() {
                Image($r("app.media.trash"))
                    .objectFit(ImageFit.Cover)
                    .width('60%')
                    .height('60%')
            }
            .backgroundColor("#FF0000")
            .type(ButtonType.Circle)
            .width(40)
            .height(40)
            .onClick(() => {
                this.listViewModel.deleteCommandEntry(entry.toCommandEntry());
            })
        }
        .margin({
            left: '3%'
        })
    }

    // 编辑按钮
    @Builder
    EditButton(entry: CommandEntryViewModel) {
        Row() {
            Button() {
                Image($r("app.media.square_and_pencil"))
                    .objectFit(ImageFit.Cover)
                    .width('60%')
                    .height('60%')
            }
            .backgroundColor("#00FF00")
            .type(ButtonType.Circle)
            .width(40)
            .height(40)
            .onClick(() => {
                this.safeCloseSwipeActions();
                this.pageStack.pushPath({
                    name: "EditPage",
                    param: [this.listViewModel, entry],
                    onPop: async (popInfo) => {
                        await this.returnFromSubPage(popInfo);
                    }
                });
            })
        }
        .margin({
            left: '3%'
        })
    }

    // ASF 发送指令时显示
    // 阻止用户操作
    @Builder
    LoadingContent() {
        Stack() {
            Column()
                .width('100%')
                .height('100%')
                .backgroundColor('#00000080')
                .blur(8)
                .onClick(() => {
                })

            Column() {
                Progress({ value: 0, total: 100, type: ProgressType.Ring })
                    .width(22)
                    .color(Color.Blue)
                    .style({
                        strokeWidth: 18,
                        status: ProgressStatus.LOADING
                    })

                Text($r("app.string.Index_processing"))
                    .margin({ top: 20 })
                    .fontSize(17)
            }
            .width('100%')
            .height('100%')
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
                .width('100%')
                .height('100%')
                .backgroundColor('#00000080')
                .blur(10)
                .onClick(() => {})

            Column() {
                Text($r("app.string.Index_Setup_Alert_Label"))
                    .fontSize(20)
                    .margin(5)
                Button($r("app.string.Index_Setup_Button_Label"))
                    .margin(5)
                    .onClick(() => {
                        this.pageStack.pushPath({
                            name: "SettingsPage",
                            onPop: async (popInfo) => {
                                await this.checkSettingsAndInit();
                                await this.returnFromSubPage(popInfo);
                            }
                        });
                        this.showSetupDialog = false;
                    })
            }
            .width('100%')
            .height('100%')
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

    // 主要界面
    @Builder
    MainContent() {
        Column() {
            if (this.listViewModel.commandEntries.length === 0) {
                Column() {
                    Text($r("app.string.Index_No_Commands_Label"))
                        .fontSize(18)
                        .fontColor(Color.Gray)
                    Text($r("app.string.Index_Create_First_Command_Label"))
                        .fontSize(14)
                        .fontColor(Color.Gray)
                        .margin({ top: 10 })
                }
                .justifyContent(FlexAlign.Center)
                .layoutWeight(1)
                .width('100%')
            } else {
                List({ scroller: this.scrollerForList }) {
                    ForEach(this.listViewModel.commandEntries, (item: CommandEntryViewModel) => {
                        ListItem() {
                            CommandListItem({
                                item: item,
                                onAccountInput: () => this.inputPopup("Account"),
                                onIDInput: () => this.inputPopup("ID"),
                                onSendCommand: (command: string) => this.sendCommand(command),
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
                            top: '2%',
                            left: '1%',
                            right: '3%',
                            bottom: '2%'
                        })
                    })
                }
                .padding(8)
                .layoutWeight(1)
                .height('100%')
                .width('100%')
            }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
    }

    build() {
        Stack() {
            Navigation(this.pageStack) {
                Stack({ alignContent: Alignment.Top }) {
                    if(!this.showSetupDialog) this.MainContent();
                }
            }
            .menus([
                {
                    value: $r("app.string.Index_Add_Menu_Button_Label"),
                    icon: $r("app.media.startIcon"),
                    action: () => {
                        this.safeCloseSwipeActions();
                        this.pageStack.pushPath({
                            name: "AddCommand",
                            param: this.listViewModel,
                            onPop: async (popInfo) => {
                                await this.checkSettingsAndInit();
                                await this.returnFromSubPage(popInfo);
                            }
                        });
                    }
                },
                {
                    value: $r("app.string.Index_Settings_Menu_Button_Label"),
                    icon: $r("app.media.startIcon"),
                    action: () => {
                        this.safeCloseSwipeActions();
                        this.pageStack.pushPath({
                            name: "SettingsPage",
                            onPop: async (popInfo) => {
                                await this.checkSettingsAndInit();
                                await this.returnFromSubPage(popInfo);
                            }
                        });
                    }
                }
            ])
            .title($r("app.string.Index_Title"))
            .mode(NavigationMode.Auto)
            .height('100%')
            .width('100%')
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
