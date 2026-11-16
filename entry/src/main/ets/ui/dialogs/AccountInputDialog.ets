import { TextInputDialog } from './TextInputDialog';

/**
 * 账号输入对话框（路由登记名保留，C7 / D8）。
 *
 * 实现只有一份，在 `TextInputDialog`；本文件只剩路由表要的两个名字——`route_map.json` 按
 * `pageSourceFile` + `buildFunction` 登记，删文件就要改路由表。
 *
 * 这里不再套一层自定义组件：多一层就等于在 `HdsNavDestination` 上再盖一层壳，
 * 而本文件要的只是「用本对话框的标题装同一份实现」。
 */
@Builder
export function AccountInputDialogBuilder() {
    TextInputDialog({ title: $r("app.string.Account_Input_Dialog_Label") });
}
