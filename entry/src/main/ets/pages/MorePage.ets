import { common } from '@kit.AbilityKit';
import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';
import bundleManager from '@ohos.bundle.bundleManager';

import Logger from '../common/utils/Logger';
import StyleConstants from '../common/constants/StyleConstants';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { DB } from '../common/utils/DB';
import { MoreMenuItem } from '../view/components/MoreMenuItem';
import CommonUtils from '../common/utils/CommonUtils';
import { ExportJson, SettingsJsonObject } from '../model/JsonObjects';
import CommonConstants from '../common/constants/CommonConstants';
import { CommandEntryViewModel } from '../viewmodel/CommandEntryViewModel';

@Builder
export function MorePageBuilder() {
    MorePage();
}

@Entry
@ComponentV2
struct MorePage {
    private LOG_TAG = '[pages/More]';

    @Local private isProcessing: boolean = false;

    @Local versionName: string = '';
    @Local versionCode: string = '';

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;
    private promptAction = this.uiContext.getPromptAction();

    pathStack: NavPathStack | undefined = undefined;

    private db = DB.getInstance();

    private listViewModel: CommandEntryListViewModel = new CommandEntryListViewModel();
    private newCommandViewModel: CommandEntryViewModel = new CommandEntryViewModel();

    private settingsEntries: Array<[Resource, Resource, () => void | Promise<void>]> = [
      [
        $r("app.string.More_Settings_Label"), $r("app.media.gearshape"),
          () => {
            this.pathStack?.pushPath(
              {
                  name: "ASFSettingsPage",
                  onPop: (popInfo) => {
                      CommonUtils.returnFromSubPage(popInfo);
                  }
              }
          );}
      ],
      [
          $r("app.string.Color_Mode_Settings_Title"), $r("app.media.brush"),
          () => {
            this.pathStack?.pushPath(
              {
                  name: "ColorModeSettingsPage",
                  onPop: (popInfo) => {
                      CommonUtils.returnFromSubPage(popInfo);
                  }
              }
            )}
      ]
    ];

    private functionEntries: Array<[Resource, Resource, () => void | Promise<void>]> = [
      [ $r("app.string.More_Export_Label"), $r("app.media.arrow_up_circle"), async () => { await this.export(); } ],
      [ $r("app.string.More_Import_Label"), $r("app.media.arrow_down_circle"), async () => { await this.importConfirm(); } ]
    ];

    private otherEntries: Array<[Resource, Resource, () => void | Promise<void>]> = [
      [ $r("app.string.More_Clear_Label"), $r("app.media.clean"), () => { this.clear(); } ]
    ];

    aboutToAppear(): void {
        try {
            let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
            this.versionName = bundleInfo.versionName;
            this.versionCode = bundleInfo.versionCode.toString();
        } catch (error) {
            Logger.error(this.LOG_TAG, `同步获取失败: ${error.message}`);
        }
    }

    async export(): Promise<void> {
        try {
            const settingsJsonObject = new SettingsJsonObject(
                await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address),
                await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password)
            );
            const commandEntryJsonObjectList = await this.listViewModel.toCommandEntryJsonObjectList();

            const exportJson = new ExportJson(settingsJsonObject, commandEntryJsonObjectList);

            const jsonString = JSON.stringify(exportJson, null, 4);

            const success = await CommonUtils.saveToFile(jsonString, this.context);

            if (success) CommonUtils.alert($r("app.string.More_Export_Success"), this.promptAction);
            else Logger.warn(this.LOG_TAG, `导出取消`);
        } catch (err) {
            CommonUtils.alert($r("app.string.More_Export_Failed"), this.promptAction);
            Logger.error(this.LOG_TAG, `导出失败, ${err}`)
        }
    }

    async import() {
        try {
            const uris = await CommonUtils.pickFile(this.context);

            // set to true, blocking user actions
            this.isProcessing = true;

            if (uris.length > 0) {
                let backupFilePath: string = uris[0];
                Logger.debug(this.LOG_TAG, `备份文件路径: ${backupFilePath}`);

                const jsonString = await CommonUtils.readFile(backupFilePath);

                if(jsonString === undefined) throw new Error("读取文件失败");

                const exportJson = await CommonUtils.parseData(jsonString);

                // 清空表
                await this.db.clearTableSettings();
                await this.listViewModel.clearCommandEntry();

                // 恢复ASF设置
                const success1 = await this.db.saveSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address, exportJson.Settings.Address);
                const success2 = await this.db.saveSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password, exportJson.Settings.Password);

                if(!success1 || !success2) throw new Error("恢复ASF设置失败");

                let commandOrder = 0;

                // 恢复ASF指令
                for(let commandEntryJsonObject of exportJson.CommandEntryList) {
                    this.newCommandViewModel.nickname = commandEntryJsonObject.Nickname;
                    this.newCommandViewModel.command = commandEntryJsonObject.Command;
                    this.newCommandViewModel.orderIndex = commandEntryJsonObject.OrderIndex == -1 ? commandOrder : commandEntryJsonObject.OrderIndex;
                    this.newCommandViewModel.accountInputRequired = commandEntryJsonObject.AIR;
                    this.newCommandViewModel.idInputRequired = commandEntryJsonObject.IIR;

                    await this.listViewModel.addCommandEntry(this.newCommandViewModel.toCommandEntry());

                    commandOrder++;
                }

                CommonUtils.alert($r("app.string.More_Import_Success"), this.promptAction);

                this.pathStack?.pop("OK");
            } else Logger.warn(this.LOG_TAG, "未选择文件");
        } catch (err) {
            Logger.error(this.LOG_TAG, `导入失败, 代码: ${err.code}, 错误信息: ${err.message}`);
            CommonUtils.alert(err.message, this.promptAction);
        } finally {
            this.isProcessing = false;
        }
    }

    async importConfirm() {
        this.promptAction.showDialog({
            title: $r("app.string.More_Import_Confirm_Title"),
            message: $r("app.string.More_Import_Confirm_Content"),
            buttons: [
                {
                    text: $r("app.string.More_Confirm_Button_Confirm"),
                    color: $r("app.color.more_confirm_button_color")
                },
                {
                    text: $r("app.string.More_Confirm_Button_Cancel"),
                    color: $r("app.color.more_confirm_button_color")
                }
            ]
        }).then(async (result) => {
            if(result.index == 0) await this.import();
            else Logger.debug(this.LOG_TAG, "导入已取消");
        });
    }

    clear() {
        try {
            this.promptAction.showDialog({
                title: $r("app.string.More_Clear_Confirm_Title"),
                message: $r("app.string.More_Clear_Confirm_Content"),
                buttons: [
                    {
                        text: $r("app.string.More_Confirm_Button_Confirm"),
                        color: $r("app.color.more_confirm_button_color")
                    },
                    {
                        text: $r("app.string.More_Confirm_Button_Cancel"),
                        color: $r("app.color.more_confirm_button_color")
                    }
                ]
            }).then(async (result) => {
                if (result.index == 0) {
                    const success = await this.listViewModel.clearCommandEntry();
                    if (success) {
                        CommonUtils.alert($r("app.string.More_Clear_Success"), this.promptAction);
                        this.pathStack?.pop("Clear press");
                    } else CommonUtils.alert($r("app.string.More_Clear_Failed_Try_Again"), this.promptAction);
                } else Logger.debug(this.LOG_TAG, "清除已取消");
            });
        } catch (err) {
            Logger.error(this.LOG_TAG, `清除失败, ${err}`);
            CommonUtils.alert($r("app.string.More_Clear_Failed"), this.promptAction);
        }
    }

    // 导入时显示
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

    @Builder
    EntryGroup(entries: Array<[Resource, Resource, () => void | Promise<void>]>) {
        Column() {
            ForEach(entries, (item: [Resource, Resource, () => void | Promise<void>]) => {
                MoreMenuItem(
                    {
                        menuText: item[0],
                        menuIcon: item[1],
                        doJob: item[2]
                    }
                )
            })
        }
        .width(StyleConstants.FULL_PERCENT)
    }

    @Builder
    EntryDivider() {
        Divider()
            .lineCap(LineCapStyle.Round)
            .strokeWidth(StyleConstants.MORE_MENU_DIVIDER_STOKE_WIDTH)
            .width(StyleConstants.NINETY_PERCENT)
    }

    @Builder
    VersionFooter() {
        Text(`${this.versionName} (${this.versionCode})`)
            .width(StyleConstants.FULL_PERCENT)
            .fontColor(Color.Grey)
            .fontSize(StyleConstants.MORE_MENU_VERSION_FONT_SIZE)
            .alignSelf(ItemAlign.End)
            .textAlign(TextAlign.Center)
    }

    build() {
        HdsNavDestination() {
            Stack({ alignContent: Alignment.Top }) {
                Column() {
                    Column() {
                        this.EntryGroup(this.settingsEntries);

                        this.EntryDivider();

                        this.EntryGroup(this.functionEntries);

                        this.EntryDivider();

                        this.EntryGroup(this.otherEntries);
                    }
                    .height(StyleConstants.FULL_PERCENT)
                    .width(StyleConstants.FULL_PERCENT)

                    this.VersionFooter();
                }
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)

                if (this.isProcessing) {
                    this.LoadingContent();
                }
            }
        }
        .titleBar({
            content: {
                title: {
                    mainTitle: $r("app.string.More_Title")
                }
            },
            style: {
                systemMaterialEffect: {
                    materialType: hdsMaterial.MaterialType.ADAPTIVE,
                    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                }
            },
            enableComponentSafeArea: true
        })
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
            this.listViewModel = context.pathInfo.param as CommandEntryListViewModel;
        })
        .onBackPressed(() => {
            this.pathStack?.pop("Back pressed");
            return true;
        })
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Loaded!");
        })
    }
}