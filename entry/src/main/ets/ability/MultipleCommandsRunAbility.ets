import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';

import Logger from '../common/utils/Logger';
import CommonConstants from '../common/constants/CommonConstants';
import PageContext from '../ui/common/PageContext';
import { CardRunPipeline } from '../domain/card/CardRunPipeline';
import { MultipleCardAdapter } from '../domain/card/MultipleCardAdapter';

/**
 * 多指令卡片的运行入口（设计 §2.5）：薄壳——生命周期钩子 + 构造管线与自己的 adapter。
 * 运行 / 取消的步骤顺序、超时、保活、终态写入都在 `CardRunPipeline`；
 * 卡片字段形状（含 `commandList` 的两种入参形态）在 `MultipleCardAdapter`。
 *
 * `launchType: multiton`（`module.json5`）：每次卡片 `call` 拉起一个新实例，
 * 取消实例靠进程内的 `CardRunSession` 拿到运行实例登记的中断函数。
 */
export default class MultipleCommandsRunAbility extends UIAbility {
    private LOG_TAG = '[MultipleCommandsRunAbility]';

    private pipeline: CardRunPipeline | null = null;

    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        Logger.debug(this.LOG_TAG, `onCreate()`);

        this.pipeline = new CardRunPipeline(
            new MultipleCardAdapter(
                this.resolveText($r("app.string.Form_Run_Cancelled_Message").id, '已取消'),
                this.resolveText($r("app.string.Form_Run_Failed_Message").id, '执行失败')
            ),
            this.LOG_TAG);
        this.pipeline.attachContext(this.context.getApplicationContext());

        // 直接通过 want 获取 call 事件参数
        if (!want.parameters || !want.parameters.params) {
            Logger.warn(this.LOG_TAG, `onCreate() want 为空`);
            return;
        }

        let params: Record<string, Object>;
        try {
            params = JSON.parse(want.parameters.params as string) as Record<string, Object>;
        } catch (err) {
            Logger.error(this.LOG_TAG, `onCreate() 参数解析失败, ${err}`);
            return;
        }

        const method = params['method'] as string;

        PageContext.vibrate(CommonConstants.VIBRATE_EFFECT_ID_HARD);

        if (method === CommonConstants.FORM_CALL_RUN) this.pipeline.run(params).then();
        else if (method === CommonConstants.FORM_CALL_CANCEL) this.pipeline.cancel(params).then();
        else Logger.warn(this.LOG_TAG, `onCreate() 未知 method`);
    }

    onDestroy(): void {
        Logger.debug(this.LOG_TAG, `onDestroy()`);

        if (this.pipeline) this.pipeline.onDestroy();
    }

    // 退后台交给管线申请短时任务；保活是尽力而为，失败不改变业务结果
    onBackground(): void {
        if (this.pipeline) this.pipeline.onBackground();
    }

    // 终态文案在 entry 环解析（`domain/` 不读资源）；取不到时回落到与 1.7.1 相同的字面量
    private resolveText(resourceID: number, fallback: string): string {
        try {
            return this.context.resourceManager.getStringSync(resourceID);
        } catch (err) {
            Logger.error(this.LOG_TAG, `getStringSync() 失败, ${err}`);
            return fallback;
        }
    }
}
