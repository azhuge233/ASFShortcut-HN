import { TextInputDialog } from './TextInputDialog';

/**
 * ID 输入对话框（路由登记名保留，C7 / D8）：与 `AccountInputDialog` 逐行同形，只有标题键不同。
 *
 * 两件改造前是同一份代码抄两遍（`diff` 只差函数名、结构体名与一个字符串键），实现收进 `TextInputDialog`。
 */
@Builder
export function IDInputDialogBuilder() {
    TextInputDialog({ title: $r("app.string.ID_Input_Dialog_Label") });
}
