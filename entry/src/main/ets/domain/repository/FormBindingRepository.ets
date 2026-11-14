import CommandEntry from '../model/CommandEntry';
import MultipleCommandsFormData from '../model/MultipleCommandsFormData';
import SingleCommandFormData from '../model/SingleCommandFormData';

/**
 * 卡片绑定（`ASFS_Forms_Preferences`）的存取接口。data 层实现、领域层持有（设计 §2.2、§2.3）。
 *
 * 失败语义：`unbind` / `removeByShortcutID` 在真正写失败时抛错，调用方据此判定「解绑失败」；
 * 其余方法沿用 1.7.1 的「记日志并返回空结果」。
 */
export interface FormBindingRepository {
    getSingle(formID: string): Promise<SingleCommandFormData | null>;

    getMultiple(formID: string): Promise<MultipleCommandsFormData | null>;

    bindSingle(data: SingleCommandFormData): Promise<void>;

    bindMultiple(data: MultipleCommandsFormData): Promise<void>;

    unbind(formID: string): Promise<void>;

    listSingle(): Promise<Array<[string, SingleCommandFormData]>>;

    listMultiple(): Promise<Array<[string, MultipleCommandsFormData]>>;

    /** 把条目的新昵称与新指令刷进绑定该条目的卡片，返回受影响的 formID */
    updateByShortcut(entry: CommandEntry): Promise<string[]>;

    /** 解除所有绑定该条目的卡片，返回受影响的 formID；写失败时抛错 */
    removeByShortcutID(shortcutID: number): Promise<string[]>;

    clearAll(): Promise<boolean>;
}
