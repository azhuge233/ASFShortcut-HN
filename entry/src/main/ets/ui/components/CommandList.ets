import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants';
import { ListLayout } from '../../domain/model/AppSettings';
import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';
import { CommandTile } from './CommandTile';
import PageContext from '../common/PageContext';

/**
 * 主列表容器（本批从 `Index.ets` 拆出，设计 §2.5）。
 *
 * 两种布局用两个不同容器，能力由容器决定，不在同一个容器上做条件属性：
 * 单列 `List` + `ListItem`（左滑编辑 / 删除 + `onMove` 拖拽），
 * 双列 `Grid` + `GridItem`（容器无左滑、无拖拽，长按 `bindContextMenu` 弹三项菜单）。
 *
 * 只抛事件、不持状态：编辑 / 删除 / 排序 / 运行态变化都回调页面，由页面走既有 VM 方法；
 * 生效布局由页面算好后以参数传入，本组件不读 VM、不持排序态。
 */
@ComponentV2
export struct CommandList {
    @Require @Param entries: Array<CommandEntryViewModel>;
    @Require @Param layout: ListLayout;
    @Require @Param runningIDs: Set<number>;

    // 滚动器归页面：`bindToScrollable` 与关闭左滑都要用，两种容器各配一个（设计 §2.5）
    @Require @Param listScroller: ListScroller;
    @Require @Param gridScroller: Scroller;

    // 卡片四个回调
    @Param onAccountInput: () => Promise<string> = () => Promise.resolve("");
    @Param onIDInput: () => Promise<string> = () => Promise.resolve("");
    @Param onSendCommand: (entry: CommandEntryViewModel, command: string) => Promise<void> =
        async () => {};
    @Param onRunningStateChange: (entry: CommandEntryViewModel, running: boolean) => void =
        () => {};

    // 列表容器自己的四个事件：编辑 / 删除 / 进排序 / 拖拽换位（拖拽由页面转给 VM，返回能否落位）
    @Param onEdit: (entry: CommandEntryViewModel) => void = () => {};
    @Param onDelete: (entry: CommandEntryViewModel) => void = () => {};
    @Param onSortRequest: () => void = () => {};
    @Param onMove: (from: number, to: number) => boolean = () => false;

    // 删除按钮（单列左滑）：确认框与 VM 调用留在页面
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
                this.onDelete(entry);
            })
        }
        .margin({
            left: StyleConstants.THREE_PERCENT
        })
    }

    // 编辑按钮（单列左滑）：关左滑与跳页留在页面
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
                this.onEdit(entry);
            })
        }
        .margin({
            left: StyleConstants.THREE_PERCENT
        })
    }

    // 双列长按菜单：三项固定为编辑 / 删除 / 排序；删除沿用现有二次确认（页面侧走同一条路径）
    @Builder
    TileMenu(entry: CommandEntryViewModel) {
        Menu() {
            MenuItem({
                content: $r("app.string.Index_Edit_Menu_Button_Label")
            })
                .onClick(() => {
                    this.onEdit(entry);
                })

            MenuItem({
                content: $r("app.string.Index_Deletion_Confirm")
            })
                .onClick(() => {
                    this.onDelete(entry);
                })

            MenuItem({
                content: $r("app.string.Index_Sort_Menu_Button_Label")
            })
                .onClick(() => {
                    this.onSortRequest();
                })
        }
    }

    // 单列：List + ListItem，左滑与拖拽都是既有能力
    @Builder
    SingleColumnList() {
        List({ scroller: this.listScroller, space: StyleConstants.CARD_SPACE }) {
            ForEach(this.entries, (item: CommandEntryViewModel) => {
                ListItem() {
                    CommandTile({
                        item: item,
                        layout: ListLayout.SINGLE,
                        onAccountInput: () => this.onAccountInput(),
                        onIDInput: () => this.onIDInput(),
                        onSendCommand: (command: string) => this.onSendCommand(item, command),
                        onRunningStateChange: (isRunning: boolean) => {
                            this.onRunningStateChange(item, isRunning);
                        }
                    })
                }
                .enabled(!this.runningIDs.has(item.id))
                .swipeAction({
                    end: {
                        builder: () => {
                            this.EditButton(item);
                            this.DeleteButton(item);
                        }
                    }
                })
            }, (item: CommandEntryViewModel) => item.id.toString())
                .onMove((from: number, to: number) => {
                    // 同步返回、失败按 DB 顺序回滚：VM 落库失败时调 onMoveFailed
                    return this.onMove(from, to);
                }, {
                    onLongPress: () => {
                        PageContext.vibrate(CommonConstants.VIBRATE_EFFECT_ID_SOFT);
                    }
                })
        }
        // 底部让出量走内容末尾留白，不写在容器 `padding` 上（设计 §2.4 / F6）：
        // padding 在滚动容器上缩的是视口——视口底边被抬到胶囊上方，内容到那条线就被裁掉、
        // 永不从胶囊下面穿过。上 / 左 / 右仍是页面内边距，末尾留白 = 页面内边距 + 底带高（104vp）
        .padding({
            top: StyleConstants.PAGE_PADDING,
            right: StyleConstants.PAGE_PADDING,
            left: StyleConstants.PAGE_PADDING
        })
        .contentEndOffset(StyleConstants.PAGE_PADDING + StyleConstants.INDEX_TAB_BAR_HEIGHT)
        // 预建行数由常量给，不跟容器默认值走（设计 §2.4 / F7）
        .cachedCount(StyleConstants.LIST_CACHED_COUNT)
        // 尺寸只有一个权威：`layoutWeight` 拿剩余空间，不再叠 `height(100%)`——
        // 两个尺寸权威会在首帧量出两个不同的高，行随之重排与重建（设计 §2.4 / F7）
        .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
        .width(StyleConstants.FULL_PERCENT)
    }

    // 双列：Grid + GridItem，无左滑、无拖拽，长按挂菜单
    @Builder
    DoubleColumnList() {
        Grid(this.gridScroller) {
            ForEach(this.entries, (item: CommandEntryViewModel) => {
                GridItem() {
                    CommandTile({
                        item: item,
                        layout: ListLayout.DOUBLE,
                        onAccountInput: () => this.onAccountInput(),
                        onIDInput: () => this.onIDInput(),
                        onSendCommand: (command: string) => this.onSendCommand(item, command),
                        onRunningStateChange: (isRunning: boolean) => {
                            this.onRunningStateChange(item, isRunning);
                        }
                    })
                }
                .enabled(!this.runningIDs.has(item.id))
                .bindContextMenu(this.TileMenu(item), ResponseType.LongPress)
            }, (item: CommandEntryViewModel) => item.id.toString())
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(StyleConstants.CARD_SPACE)
        .rowsGap(StyleConstants.CARD_SPACE)
        // 让出量与单列同式，走内容末尾留白，不设容器补偿（设计 §2.4 / F6）。
        // 双列此前在这里多补一个 `INDEX_TAB_BAR_CAPSULE_HEIGHT`，是把「滚不到末排」当成了「让出量不足」：
        // 让出量 104 → 160 时净空由 16vp 抬到 72vp，差值正好一个胶囊高，说明 104vp 本来就已经给出 16vp 净空。
        // 那 56vp 反过来还压掉了 `Grid` 的渲染窗口：160vp 冷启动只建出 4 行（第 5 行整排不存在），
        // 104vp 下同一份数据建出 5 行、第 5 行上缘 2151px 落在视口底 2720px 之内。
        .padding({
            top: StyleConstants.PAGE_PADDING,
            right: StyleConstants.PAGE_PADDING,
            left: StyleConstants.PAGE_PADDING
        })
        .contentEndOffset(StyleConstants.PAGE_PADDING + StyleConstants.INDEX_TAB_BAR_HEIGHT)
        // 预建行数由常量给，不跟容器默认值走（设计 §2.4 / F7）
        .cachedCount(StyleConstants.LIST_CACHED_COUNT)
        // 尺寸只有一个权威：`layoutWeight` 拿剩余空间，不再叠 `height(100%)`（设计 §2.4 / F7）
        .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
        .width(StyleConstants.FULL_PERCENT)
    }

    build() {
        if (this.layout === ListLayout.DOUBLE) {
            this.DoubleColumnList();
        } else {
            this.SingleColumnList();
        }
    }
}
