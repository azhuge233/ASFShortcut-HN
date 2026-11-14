import { CardEditAbilityBase } from './CardEditAbilityBase';

/**
 * 多指令卡的编辑窗口（设计 §2.13）：只剩两处事实——日志标签与页面路径。
 * 窗口 `LocalStorage` 参数通道、`formID` 解析、颜色模式与页面加载都在基类。
 */
export default class MultipleCommandsEditAbility extends CardEditAbilityBase {
    protected readonly logTag: string = '[MultipleCommandsEditAbility]';
    protected readonly targetPage: string = 'ui/pages/MultipleCommandsFormEdit';
}
