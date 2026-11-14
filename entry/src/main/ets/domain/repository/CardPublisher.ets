import MultipleCommandsFormData from '../model/MultipleCommandsFormData';
import SingleCommandFormData from '../model/SingleCommandFormData';

/**
 * 卡片数据写出的接口。`data/form/FormPublisher.ets` 实现、VM 持有（设计 §2.4.1）。
 *
 * 只交领域数据模型；`FormBindingData` 的构造与卡片写入调用留在 `data/`
 * （`domain/` 禁用 FormKit，§1.5 规则 1）。两个入口按调用点的既有行为分开：
 * 重试口径不许被顺手统一（§2.2），`publish` 写一次、`publishWithRetry` 失败重试一次。
 */
export interface CardPublisher {
    /**
     * 写入一张卡片的数据。
     * `data` 为 `null` 表示写「空卡」（该卡片当前没有绑定）。
     */
    publish(formID: string, data: SingleCommandFormData | MultipleCommandsFormData | null): Promise<boolean>;

    /**
     * 写入一张卡片的数据，失败重试一次。只有运行路径走这条（1.7.1 的 `updateFormWithRetry`
     * 就是这个行为，模块档 §2.6）；原本不重试的调用点用 `publish`。
     */
    publishWithRetry(formID: string, data: SingleCommandFormData | MultipleCommandsFormData): Promise<boolean>;
}
