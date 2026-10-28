import { describe, it, expect } from '@ohos/hypium';

import { CardRunSession, RunCancelResult, RunToken } from '../main/ets/common/utils/CardRunSession';

// CardRunSession 的 token 仲裁单测：设备外可复跑的验收判据（设计 §5 的 AC4 / AC11 行）
export default function cardRunSessionTest() {
  describe('cardRunSessionTest', () => {
    it('newerTokenOwnsTerminalWrite', 0, () => {
      const session: CardRunSession = CardRunSession.getInstance();

      const oldToken: RunToken = session.begin('test-form-newer');
      const newToken: RunToken = session.begin('test-form-newer');

      // 旧 token 已被替换：不再是当前会话，运行路径的写入闸门判 false
      expect(session.isActive(oldToken)).assertFalse();
      expect(session.isActive(newToken)).assertTrue();

      // 同 formID 先后 begin 两次：旧 token 失去终态写入权
      expect(session.tryFinish(oldToken)).assertFalse();
      expect(session.tryFinish(newToken)).assertTrue();
    });

    it('cancelMarksTokenAndKeepsTerminalWrite', 0, () => {
      const session: CardRunSession = CardRunSession.getInstance();

      const token: RunToken = session.begin('test-form-cancel');
      let aborted: boolean = false;
      session.registerAbort(token, () => {
        aborted = true;
      });

      expect(session.cancel('test-form-cancel')).assertEqual(RunCancelResult.CANCELLED);
      expect(token.cancelled).assertTrue();
      expect(aborted).assertTrue();
      // 已取消的 token 不再发布运行态（卡片写入闸门判 false）
      expect(session.isActive(token)).assertFalse();

      // 取消之后终态仍由运行实例写一次
      expect(session.tryFinish(token)).assertTrue();
    });

    it('cancelWithoutSessionReturnsNone', 0, () => {
      const session: CardRunSession = CardRunSession.getInstance();

      expect(session.cancel('test-form-never-begun')).assertEqual(RunCancelResult.NONE);
    });

    it('endedAndAbandonedSessionsAreNotCancellable', 0, () => {
      const session: CardRunSession = CardRunSession.getInstance();

      const endedToken: RunToken = session.begin('test-form-ended');
      expect(session.tryFinish(endedToken)).assertTrue();
      expect(session.isActive(endedToken)).assertFalse();
      expect(session.cancel('test-form-ended')).assertEqual(RunCancelResult.ENDED);

      const abandonedToken: RunToken = session.begin('test-form-abandoned');
      session.abandon(abandonedToken);
      expect(session.isActive(abandonedToken)).assertFalse();
      expect(session.cancel('test-form-abandoned')).assertEqual(RunCancelResult.NONE);
      // 弃置前在途结果晚到：不覆盖兜底终态
      expect(session.tryFinish(abandonedToken)).assertFalse();
    });
  });
}
