import { CommandDao } from '../../data/dao/CommandDao';
import { SettingsDao } from '../../data/dao/SettingsDao';
import { AsfClient } from '../../data/network/AsfClient';
import { FormPublisher } from '../../data/form/FormPublisher';
import { FormBindingStore } from '../../data/store/FormBindingStore';
import { AppSettingsRepositoryImpl } from '../../data/store/AppSettingsStore';
import { AppSettingsRepository } from '../repository/AppSettingsRepository';
import { CardPublisher } from '../repository/CardPublisher';
import { CommandRepository } from '../repository/CommandRepository';
import { CommandSender } from '../repository/CommandSender';
import { FormBindingRepository } from '../repository/FormBindingRepository';
import { SettingsRepository } from '../repository/SettingsRepository';

/**
 * 依赖装配：把 `data/` 的实现配到 `domain/` 的端口上，供 `viewmodel/` 的默认构造参数取用。
 *
 * 为什么需要这个文件：规则 4 钉死 `viewmodel/` 只能 import `domain/` 与 `common/`（设计 §1.5、§2.4.5），
 * 而 VM 要用仓库与发送器。`domain/` 自己 import `data/` 的实现是合法方向（`CommandService`、
 * `CommandEntryList` 的默认参数一直是这么写的），所以装配点放在这里，VM 只看见接口。
 * 每个函数一行：换实现只改这里一处。
 */

/** 指令表端口 */
export function commandRepository(): CommandRepository {
    return CommandDao.getInstance();
}

/** 服务器设置端口 */
export function settingsRepository(): SettingsRepository {
    return SettingsDao.getInstance();
}

/** 卡片绑定端口 */
export function formBindingRepository(): FormBindingRepository {
    return FormBindingStore.getInstance();
}

/** 卡片写入端口（不重试的写入口，与 1.7.1 的页面/VM 调用点行为一致） */
export function cardPublisher(): CardPublisher {
    return FormPublisher.getInstance();
}

/** 应用设置端口 */
export function appSettingsRepository(): AppSettingsRepository {
    return new AppSettingsRepositoryImpl();
}

/** 发送器工厂：主实例与测试用的独立实例都从这里造，VM 不 import `data/network/` */
export function createCommandSender(): CommandSender {
    return new AsfClient();
}
