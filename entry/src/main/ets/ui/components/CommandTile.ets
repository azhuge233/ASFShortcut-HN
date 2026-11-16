import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';
import { ListLayout } from '../../domain/model/AppSettings';
import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';
import CommonConstants from '../../common/constants/CommonConstants';

@ComponentV2
export struct CommandTile {
    private LOG_TAG = "[view/components/CommandTile]";

    @Param item: CommandEntryViewModel = new CommandEntryViewModel();

    // 生效布局由页面算好传入（排序态下一律单列，设计 §2.2）；卡片只按它二选一渲染
    @Param layout: ListLayout = ListLayout.SINGLE;

    // 回调函数
    @Param onAccountInput: () => Promise<string> = () => Promise.resolve("");
    @Param onIDInput: () => Promise<string> = () => Promise.resolve("");
    @Param onSendCommand: (command: string) => Promise<void> = async () => {};
    @Param onRunningStateChange: (processing: boolean) => void = () => {};

    @Local isRunning: boolean = false;

    // 运行蒙版的遮罩高度：内容包裹层 `onAreaChange` 回填的实测高度（vp），不用百分比高度（设计 §2.3）
    @Local contentHeight: number = 0;

    // 设置条目运行状态
    // 设置本地运行状态参数，控制加载覆盖层的显示
    // 再向回调函数传出运行状态，供主页面控制本条目的启用/禁用
    private changeRunningState(isRunning: boolean) {
        this.isRunning = isRunning;
        this.onRunningStateChange(isRunning);
    }

    // 点击执行按钮后执行指令
    // 根据条目设置，弹出对应的输入页面
    private async runCommand() {
        try {
            this.changeRunningState(true);
            let command = this.item.command;

            if (this.item.accountInputRequired === 1 && this.onAccountInput) {
                let asfAcc = await this.onAccountInput();
                if(asfAcc === "") {
                    Logger.debug(this.LOG_TAG, `未输入ASF账户，取消执行`);
                    return;
                } else command = `${command} ${asfAcc}`;
            }

            if (this.item.idInputRequired === 1 && this.onIDInput) {
                let asfId = await this.onIDInput();
                if(asfId === "") {
                    Logger.debug(this.LOG_TAG, `未输入App/Sub/Def ID，取消执行`);
                    return;
                } else command = `${command} ${asfId}`;
            }

            await this.onSendCommand(command);
        } catch (err) {
            Logger.error(this.LOG_TAG, `<runCommand> error: ${err}`);
        } finally {
            this.changeRunningState(false);
        }
    }

    // 运行时的覆盖层（单列用）：遮罩「铺满 + 拦点击」，自身的模糊与底色都不需要（模糊由内容包裹层施加）
    @Builder
    RunningBlock() {
        Column()
            .width(StyleConstants.FULL_PERCENT)
            .height(this.contentHeight)
            .onClick(() => {})

        Column() {
            Progress({ value: 0, total: 100, type: ProgressType.Ring })
                .width(StyleConstants.COMMAND_TILE_PROGRESS_WIDTH)
                .style({
                    strokeWidth: StyleConstants.COMMAND_TILE_PROGRESS_STROKE_WIDTH,
                    status: ProgressStatus.LOADING,
                    shadow: true,
                    enableScanEffect: true,
                    enableSmoothEffect: true
                })
        }
        .width(StyleConstants.FULL_PERCENT)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {})
    }

    // 条目的主要内容（单列）：结构不动，卡面（描边 / 底色 / 圆角）加到 `build()` 的卡片根上
    @Builder
    MainContent() {
        Row() {
            Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE }) {
                Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE / 2 }) {
                    Text(this.item.nickname)
                        .fontSize(StyleConstants.COMMAND_TILE_NAME_FONT_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(StyleConstants.FULL_PERCENT)

                    Text(this.item.command)
                        .fontSize(StyleConstants.COMMAND_TILE_COMMAND_FONT_SIZE)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(StyleConstants.FULL_PERCENT)
                }
                .width(StyleConstants.FULL_PERCENT)

                Row({ space: StyleConstants.COMMAND_TILE_ROW_SPACE }) {
                    if (this.item.accountInputRequired === 1 || this.item.idInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .margin({
                                right: StyleConstants.PADDING_TWO
                            })
                    }

                    if (this.item.accountInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_Account_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .fontColor($r('app.color.tag_account_text'))
                            .backgroundColor($r('app.color.tag_account_bg'))
                            .padding({
                                left: StyleConstants.PADDING_EIGHT,
                                right: StyleConstants.PADDING_EIGHT,
                                top: StyleConstants.PADDING_TWO,
                                bottom: StyleConstants.PADDING_TWO
                            })
                            .borderRadius(StyleConstants.CONTROL_RADIUS)
                    }

                    if (this.item.idInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_ID_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .fontColor($r('app.color.tag_id_text'))
                            .backgroundColor($r('app.color.tag_id_bg'))
                            .padding({
                                left: StyleConstants.PADDING_EIGHT,
                                right: StyleConstants.PADDING_EIGHT,
                                top: StyleConstants.PADDING_TWO,
                                bottom: StyleConstants.PADDING_TWO
                            })
                            .borderRadius(StyleConstants.CONTROL_RADIUS)
                    }

                    // 如果没有标签，添加一个占位空间保持高度一致
                    if (this.item.accountInputRequired === 0 && this.item.idInputRequired === 0) {
                        Text(' ')
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .opacity(0)
                    }
                }
                .width(StyleConstants.FULL_PERCENT)
            }
            .width(StyleConstants.SEVENTY_FIVE_PERCENT)
            // 内边距收敛到卡片内边距一个值，左右不再 20 / 16 不对称（设计 §2.2 ④）
            .padding(StyleConstants.CARD_PADDING)

            Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE }) {
                Button(this.isRunning ? $r("app.string.CommandTile_Button_Label_Running") :
                    $r("app.string.CommandTile_Button_Label_Run"))
                    .enabled(!this.isRunning)
                    .stateEffect(true)
                    .onClick(() => {
                        PageContext.vibrate(CommonConstants.VIBRATE_EFFECT_ID_HARD);
                        this.runCommand();
                    })
            }
            .width(StyleConstants.TWENTY_FIVE_PERCENT)
            .padding({
                right: StyleConstants.PADDING_TWO
            })
        }
    }

    // 右下角的圆形动作位（双列）：运行中在按钮位原地换成进度环——
    // 环的取景框比按钮槽位大，外层 Stack 固定成槽位尺寸并按中心对齐，框因此向四周对称溢出；
    // Stack 不裁子节点（`clip` false），卡根的 `clip` 只切卡外，框整体仍在卡面内。
    // 最终构建实读（mate60pro，3.25px/vp）：外径 118–122px ≈ 37vp、内孔 ≈ 21vp、线宽 26px = 8.0vp，
    // 环心与钮心差 ≤1vp。落位见设计 §2.2 ③「按钮位原地替换」，框与槽位的关系见本方法。
    // 环色显式取品牌蓝（`.color`）：环与右下播放钮同色同源。
    // 实测（mate60pro 1260×2720，3.25px/vp；卡面灰度 255）：扫描高光最暗 175（差 80，判据 ≥40 成立）；
    // 轨道中位 248（差 7）——`backgroundColor` 就是环轨道的取色口（值探针 `Color.Gray` 实测轨道 199），
    // 但 `comp_background_gray` 在浅色主题下仍偏浅，未落进 15–40 的区间；换键取值为观感取舍，待父侧定
    @Builder
    CompactActionSlot() {
        if (this.isRunning) {
            // 外层 Stack 固定成按钮的槽位尺寸，取景框比槽位大、在槽位里居中溢出：
            // 槽位本身不能跟着取景框变大，否则环心会离钮心 6vp（差值的半）
            Stack({ alignContent: Alignment.Center }) {
                Progress({ value: 0, total: 100, type: ProgressType.Ring })
                    .width(StyleConstants.CARD_PLAY_PROGRESS_BOX_SIZE)
                    .height(StyleConstants.CARD_PLAY_PROGRESS_BOX_SIZE)
                    .color($r("sys.color.brand"))
                    // 轨道底取系统色：`backgroundColor` 就是环轨道的取色口，取值与读数见本方法头注释
                    .backgroundColor($r("sys.color.comp_background_gray"))
                    .style({
                        strokeWidth: StyleConstants.CARD_PLAY_PROGRESS_STROKE,
                        status: ProgressStatus.LOADING,
                        shadow: true,
                        enableScanEffect: true,
                        enableSmoothEffect: true
                    })
            }
            .width(StyleConstants.CARD_PLAY_BUTTON_SIZE)
            .height(StyleConstants.CARD_PLAY_BUTTON_SIZE)
        } else {
            Button() {
                SymbolGlyph($r("sys.symbol.play_fill"))
                    .fontSize(StyleConstants.CARD_PLAY_ICON_SIZE)
                    .fontColor([Color.White])
            }
            .type(ButtonType.Circle)
            .width(StyleConstants.CARD_PLAY_BUTTON_SIZE)
            .height(StyleConstants.CARD_PLAY_BUTTON_SIZE)
            .backgroundColor($r("sys.color.brand"))
            .stateEffect(true)
            .onClick(() => {
                PageContext.vibrate(CommonConstants.VIBRATE_EFFECT_ID_HARD);
                this.runCommand();
            })
        }
    }

    // 条目的主要内容（双列紧凑）：文本列占满整卡宽，「账号」「ID」两枚徽章同行；
    // 播放钮叠在卡片右下角，只有指令那一行让出钮宽——昵称行在钮的上方、纵向不相交，
    // 不再跟着让，昵称因此能占满整行（批档 §1「用户裁定（2026-11-15 10:56，双列昵称占满整行）」）
    @Builder
    CompactContent() {
        Stack({ alignContent: Alignment.BottomEnd }) {
            Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE / 2 }) {
                Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE / 2 }) {
                    Text(this.item.nickname)
                        .fontSize(StyleConstants.COMMAND_TILE_NAME_FONT_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(StyleConstants.FULL_PERCENT)

                    Text(this.item.command)
                        .fontSize(StyleConstants.COMMAND_TILE_COMMAND_FONT_SIZE)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(StyleConstants.FULL_PERCENT)
                        // 让出量只加在指令这一行：昵称行在 y=16–35vp、钮在 y=65–101vp，纵向不相交；
                        // 指令第二行与钮同带，必须让（批档 §1 用户裁定 2026-11-15 10:56）
                        .padding({ right: StyleConstants.CARD_PLAY_BUTTON_SIZE + StyleConstants.PADDING_EIGHT })
                }
                .width(StyleConstants.FULL_PERCENT)
                // 徽章行也不用让：两枚徽章共 80vp，右缘离钮左缘仍有余量，不撞（设计 §2.2 ② 的宽度预算）

                // 双列不显示前缀（双列放不下），两枚徽章之间 4vp；宽度不够时整枚被裁而不是折行：
                // 「不折行」是需求 U2 的明文，宽度预算见设计 §2.2 ②
                Row({ space: StyleConstants.PADDING_TWO * 2 }) {
                    if (this.item.accountInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_Account_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .fontColor($r('app.color.tag_account_text'))
                            .backgroundColor($r('app.color.tag_account_bg'))
                            .padding({
                                left: StyleConstants.PADDING_EIGHT,
                                right: StyleConstants.PADDING_EIGHT,
                                top: StyleConstants.PADDING_TWO,
                                bottom: StyleConstants.PADDING_TWO
                            })
                            .borderRadius(StyleConstants.CONTROL_RADIUS)
                            .margin({ top: StyleConstants.PADDING_TWO })
                    }

                    if (this.item.idInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_ID_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .fontColor($r('app.color.tag_id_text'))
                            .backgroundColor($r('app.color.tag_id_bg'))
                            .padding({
                                left: StyleConstants.PADDING_EIGHT,
                                right: StyleConstants.PADDING_EIGHT,
                                top: StyleConstants.PADDING_TWO,
                                bottom: StyleConstants.PADDING_TWO
                            })
                            .borderRadius(StyleConstants.CONTROL_RADIUS)
                            .margin({ top: StyleConstants.PADDING_TWO })
                    }

                    // 没有标签时同样留一行高度，两种内容形态的卡片高度才一致
                    if (this.item.accountInputRequired === 0 && this.item.idInputRequired === 0) {
                        Text(' ')
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .opacity(0)
                    }
                }
                .width(StyleConstants.FULL_PERCENT)
            }
            .width(StyleConstants.FULL_PERCENT)
            // 撑满卡片根的高度：卡高由根上的 `CARD_HEIGHT_DOUBLE` 定，内容不去撑它
            .height(StyleConstants.FULL_PERCENT)
            .alignItems(HorizontalAlign.Start)
            // U9：内容块贴顶、徽章行贴底。固定卡高下余量本来全堆底部，徽章行会悬在空中、
            // 与卡片下缘的距离随内容高度浮动；SpaceBetween 把余量分到两块之间，两种卡片同一构造
            .justifyContent(FlexAlign.SpaceBetween)
            .padding(StyleConstants.CARD_PADDING)
            // 运行中只模糊文本列：右下进度环要看得清才是指示（单列的居中环同样在模糊层之外）
            .blur(this.isRunning ? StyleConstants.BLUE_LEVEL : 0)

            // 叠放在右下角：落位由容器对齐表达，不再靠行尾垂直居中；
            // 右 / 下各留一个卡片内边距，钮的外缘与卡片描边同距（设计 §2.2 ③）
            Column() {
                this.CompactActionSlot();
            }
            .margin({
                right: StyleConstants.CARD_PADDING,
                bottom: StyleConstants.CARD_PADDING
            })
        }
            .width(StyleConstants.FULL_PERCENT)
            .height(StyleConstants.FULL_PERCENT)
    }

    build() {
        Stack({ alignContent: Alignment.Center }) {
            if (this.layout === ListLayout.DOUBLE) {
                this.CompactContent();
            } else {
                // 模糊施加在内容包裹层：模糊区即内容盒本身，「与卡片同高」由构造成立
                Column() {
                    this.MainContent();
                }
                .width(StyleConstants.FULL_PERCENT)
                .blur(this.isRunning ? StyleConstants.BLUE_LEVEL : 0)
                .onAreaChange((_old: Area, now: Area) => {
                    this.contentHeight = Number(now.height);
                })
            }

            // 居中进度环只服务单列；双列的指示在右下动作位（设计 §2.2 ③）
            if (this.isRunning && this.layout === ListLayout.SINGLE) {
                this.RunningBlock();
            }
        }
        .width(StyleConstants.FULL_PERCENT)
        // 双列固定高度：同屏卡片等高靠这一个常量，不靠内容撑开（设计 §2.2 ①）；
        // 单列不固定——单列一行一张、参差不可见，固定高度反而会裁掉两行以上的指令（设计 §4）
        .height(this.layout === ListLayout.DOUBLE ? StyleConstants.CARD_HEIGHT_DOUBLE :
            LayoutPolicy.wrapContent)
        .backgroundColor($r("sys.color.comp_background_primary"))
        .border({ width: StyleConstants.CARD_BORDER_WIDTH, color: $r("sys.color.comp_divider") })
        .borderRadius(StyleConstants.CARD_RADIUS)
        .clip(true)
    }
}
