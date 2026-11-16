import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import { CommandEditViewModel } from '../../viewmodel/CommandEditViewModel';
import { AddCommandForm } from '../components/AddCommandForm';
import { AppPage } from '../components/AppPage';

@Builder
export function AddCommandBuilder() {
    AddCommand();
}

/**
 * 新增指令页（设计 §2.5）：**页面壳保留**，表单体在 `ui/components/AddCommandForm.ets`。
 *
 * 保留的理由是桌面长按快捷方式绕开 `Index` 直达本页——`shortcuts_config.json` 的 `shortCutKey`、
 * `EntryAbility` 的 `VALID_TARGET_PAGES`、`route_map.json` 的 `AddCommandBuilder` 三处登记都在盘，
 * 删壳等于删一个用户可见入口。页面内入口已改为底栏第三个页签，这个壳只服务那条快捷方式链路。
 *
 * 两条路径共用同一个表单组件：本页的 `onSaved` 是空函数（保持原「留在原地」行为），
 * 页签宿主的 `onSaved` 会切回指令列表。
 *
 * 外壳只给导航栏（`scrollable: false`）：滚动由 `AddCommandForm` 自己管，套两层滚动会互相抢手势。
 */
@Entry
@ComponentV2
struct AddCommand {
    private LOG_TAG = '[pages/AddCommand]';

    // 路由参数到达前先占一个空 VM，`onReady` 拿到真正的列表 VM 后替换
    @Local viewModel: CommandEditViewModel = new CommandEditViewModel(new CommandListViewModel());

    pathStack: NavPathStack | undefined = undefined;

    @LocalBuilder
    pageContent() {
        AddCommandForm({
            viewModel: this.viewModel,
            // 快捷方式路径保持原行为：保存后留在本页，不切换任何页签
            onSaved: () => {}
        })
    }

    build() {
        // `@Entry` 的 build 根节点必须是容器组件，自定义组件不能当根，所以包一层占满视口的 `Column`
        Column() {
            AppPage({
                title: $r("app.string.AddCommand_Title"),
                logTag: this.LOG_TAG,
                scrollable: false,
                content: this.pageContent,
                onReady: (context: NavDestinationContext) => {
                    this.pathStack = context.pathStack;
                    // 路由参数带的是主列表的 VM：新增要落库并刷新列表与卡片，走的就是它
                    const param: CommandListViewModel = context.pathInfo.param as CommandListViewModel;
                    if (param instanceof CommandListViewModel) {
                        this.viewModel = new CommandEditViewModel(param);
                    } else {
                        Logger.warn(this.LOG_TAG, `未收到列表 VM，保留占位实例`);
                    }
                    this.viewModel.startAdd();
                }
            })
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
    }
}
