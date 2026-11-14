import MultipleCommandsFormData from '../model/MultipleCommandsFormData';
import SingleCommandFormData from '../model/SingleCommandFormData';

/**
 * 卡片数据写出的接口。`data/form/FormPublisher.ets` 实现、VM 持有（设计 §2.4.1）。
 *
 * 只交领域数据模型；`FormBindingData` 的构造与 `formProvider` 调用留在 `data/`
 * （`domain/` 禁 `@kit.FormKit`，§1.5 规则 1）。失败即返回 false，不重试——
 * 重试口径按调用点区分，加不加由实现决定（§2.2）。
 */
export interface CardPublisher {
    /**
     * 写入一张卡片的数据。
     * `data` 为 `null` 表示写「空卡」（该卡片当前没有绑定）。
     */
    publish(formID: string, data: SingleCommandFormData | MultipleCommandsFormData | null): Promise<boolean>;
}
