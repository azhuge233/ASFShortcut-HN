import { backgroundTaskManager } from '@kit.BackgroundTasksKit';

import Logger from './Logger';

const LOG_TAG: string = '[KeepAlive]';

/**
 * 短时任务（`@kit.BackgroundTasksKit`）的薄封装。
 *
 * 放 `common/` 而不是 `domain/card/`：`domain/` 一条 kit 都不 import（§1.5 规则 1 的读法收紧到零）。
 * 「什么时候申请、要求多少额度、什么时候释放」仍由 `CardRunPipeline` 决定，这里只有 OS 调用本身。
 * 返回 -1 表示没申请到——保活是尽力而为，失败不改变业务结果（硬超时兜底）。
 */
export function requestKeepAlive(reason: string, expectedMs: number, onExpire: () => void): number {
    try {
        const suspendInfo = backgroundTaskManager.requestSuspendDelay(reason, onExpire);

        if (suspendInfo.actualDelayTime < expectedMs) {
            Logger.warn(LOG_TAG, `短时任务额度 ${suspendInfo.actualDelayTime}ms 小于 ${expectedMs}ms，由硬超时兜底`);
        }

        return suspendInfo.requestId;
    } catch (err) {
        Logger.error(LOG_TAG, `申请短时任务失败，运行与终态不受影响, ${err}`);
        return -1;
    }
}

/** 释放短时任务；`requestID` 为 -1（从未申请）时什么也不做 */
export function releaseKeepAlive(requestID: number): void {
    if (requestID === -1) return;

    try {
        backgroundTaskManager.cancelSuspendDelay(requestID);
    } catch (err) {
        Logger.error(LOG_TAG, `释放短时任务失败, ${err}`);
    }
}
