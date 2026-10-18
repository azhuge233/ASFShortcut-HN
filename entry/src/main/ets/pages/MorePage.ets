import { common } from '@kit.AbilityKit';
import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';
import bundleManager from '@ohos.bundle.bundleManager';

import Logger from '../common/utils/Logger';
import StyleConstants from '../common/constants/StyleConstants';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { DB } from '../common/utils/DB';
import { MoreMenuItem } from '../view/components/MoreMenuItem';
import CommonUtils from '../common/utils/CommonUtils';
import { ExportJsonObject, SettingsJsonObject } from '../model/JsonObjects';
import CommonConstants from '../common/constants/CommonConstants';
import CommandEntry from '../model/CommandEntry';

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

    private settingsEntries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]> = [
      [
        $r("app.string.More_Settings_Label"), $r("app.media.gearshape"), $r("app.string.ASF_Settings_Desc"),
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
          $r("app.string.Color_Mode_Settings_Title"), $r("app.media.brush"), $r("app.string.Color_Mode_Desc"),
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

    private functionEntries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]> = [
      [ $r("app.string.More_Export_Label"), $r("app.media.arrow_up_circle"), $r("app.string.Export_Desc"), async () => { await this.export(); } ],
      [ $r("app.string.More_Import_Label"), $r("app.media.arrow_down_circle"), $r("app.string.Import_Desc"), async () => { await this.importConfirm(); } ]
    ];

    private otherEntries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]> = [
      [ $r("app.string.More_Clear_Label"), $r("app.media.clean"), null, async () => { await this.clear(); } ]
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
                await this.db.getSetting(CommonConstants.DB_KEY_HOST_INFO_ADDRESS),
                await this.db.getSetting(CommonConstants.DB_KEY_HOST_INFO_PASSWORD)
            );
            const commandEntryJsonObjectList = await this.listViewModel.toCommandEntryJsonObjectList();

            const exportJson = new ExportJsonObject(settingsJsonObject, commandEntryJsonObjectList);

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

                // 先构造条目，再由 DB 事务整体替换；失败时回滚，保留原数据
                const entries: Array<CommandEntry> = [];
                let commandOrder = 0;

                for (const commandEntryJsonObject of exportJson.CommandEntryList) {
                    const orderIndex = commandEntryJsonObject.OrderIndex == -1 ? commandOrder : commandEntryJsonObject.OrderIndex;
                    entries.push(new CommandEntry(
                        0,
                        commandEntryJsonObject.Nickname,
                        commandEntryJsonObject.Command,
                        orderIndex,
                        commandEntryJsonObject.AIR,
                        commandEntryJsonObject.IIR
                    ));
                    commandOrder++;
                }

                const success = await this.listViewModel.importData(
                    exportJson.Settings.Address,
                    exportJson.Settings.Password,
                    entries
                );

                if (!success) throw new Error("导入数据失败");

                CommonUtils.alert($r("app.string.More_Import_Success"), this.promptAction);

                this.pathStack?.pop("OK");
            } else Logger.warn(this.LOG_TAG, "未选择文件");
        } catch (err) {
            Logger.error(this.LOG_TAG, `导入失败, ${err}`);
            CommonUtils.alert(`导入失败: ${err}`, this.promptAction);
        } finally {
            this.isProcessing = false;
        }
    }

    async importConfirm() {
        try {
            const result = await this.promptAction.showDialog({
                title: $r("app.string.More_Import_Confirm_Title"),
                message: $r("app.string.More_Import_Confirm_Content"),
                buttons: [
                    {
                        text: $r("app.string.More_Confirm_Button_Confirm"),
                        color: $r("sys.color.font_primary")
                    },
                    {
                        text: $r("app.string.More_Confirm_Button_Cancel"),
                        color: $r("sys.color.font_primary")
                    }
                ]
            });

            if(result.index === 0) await this.import();
            else Logger.warn(this.LOG_TAG, "导入已取消");
        } catch (err) {
            if (err && (err.code === 100006 || err.message?.toLowerCase().includes('cancel'))) {
                Logger.warn(this.LOG_TAG, "用户取消对话框");
                return;
            }

            Logger.error(this.LOG_TAG, `删除确认框弹出失败`);
        }
    }

    async clear() {
        try {
            const result = await this.promptAction.showDialog({
                title: $r("app.string.More_Clear_Confirm_Title"),
                message: $r("app.string.More_Clear_Confirm_Content"),
                buttons: [
                    {
                        text: $r("app.string.More_Confirm_Button_Confirm"),
                        color: $r("sys.color.font_primary")
                    },
                    {
                        text: $r("app.string.More_Confirm_Button_Cancel"),
                        color: $r("sys.color.font_primary")
                    }
                ]
            });

            if (result.index === 0) {
                const success = await this.listViewModel.clearCommandEntry();
                if (success) {
                    CommonUtils.alert($r("app.string.More_Clear_Success"), this.promptAction);
                    this.pathStack?.pop("Clear press");
                } else CommonUtils.alert($r("app.string.More_Clear_Failed_Try_Again"), this.promptAction);
            } else Logger.warn(this.LOG_TAG, "清除已取消");
        } catch (err) {
            if (err && (err.code === 100006 || err.message?.toLowerCase().includes('cancel'))) {
                Logger.warn(this.LOG_TAG, "用户取消对话框");
                return;
            }

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

    @Builder
    EntryGroup(entries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]>) {
        Column() {
            ForEach(entries, (item: [Resource, Resource, Resource | null, () => void | Promise<void>]) => {
                MoreMenuItem(
                    {
                        menuTitleText: item[0],
                        menuIcon: item[1],
                        menuDescText: item[2],
                        doJob: item[3]
                    }
                )
            }, (item: [Resource, Resource, Resource | null, () => void | Promise<void>], index: number) => index.toString())
        }
        .width(StyleConstants.FULL_PERCENT)
    }

    @Builder
    EntryDivider() {
        Divider()
            .lineCap(LineCapStyle.Round)
            .strokeWidth(StyleConstants.MORE_MENU_DIVIDER_STROKE_WIDTH)
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