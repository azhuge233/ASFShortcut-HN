import { describe, it, expect } from '@ohos/hypium';

import CommandEntry from '../main/ets/domain/model/CommandEntry';
import CommandEntryList from '../main/ets/domain/model/CommandEntryList';
import { AppSettings, ColorMode, ListLayout } from '../main/ets/domain/model/AppSettings';
import { AppSettingsRepository } from '../main/ets/domain/repository/AppSettingsRepository';
import CommandListViewModel from '../main/ets/viewmodel/CommandListViewModel';

/**
 * B3 的 ViewModel 单测（设计 §6.1 的 U13、U14、U16）。
 *
 * 断言的是 VM 的状态与业务结果：拖拽成功即持久化、持久化失败按数据库顺序回滚、
 * 读库失败置错误态且不把列表当空。聚合根用子类替身，把「读失败 / 写失败」注入到可控状态；
 * 其余端口在本文件用不到（VM 只在导入与执行路径上取它们），因此走默认装配。
 */

// 一次 move 的落库在后台完成，`move` 本身同步返回（`List.onMove` 要求同步）。
// 替身里每个 await 都立刻结算，所以排空微任务队列即可确定性地等到落库结束——不用计时器。
async function settle(): Promise<void> {
  for (let i = 0; i < 20; i++) await Promise.resolve();
}

class FakeAggregate extends CommandEntryList {
  loadFails: boolean = false;
  persistFails: boolean = false;
  persisted: Array<CommandEntry> = [];

  private store: Array<CommandEntry> = [];

  constructor(seed: Array<CommandEntry>) {
    super([]);
    this.store = seed;
  }

  async loadCommandEntries(): Promise<boolean> {
    if (this.loadFails) throw new Error('注入的读失败');

    this.commandEntries = this.store.map(
      (entry: CommandEntry) => new CommandEntry(entry.id, entry.nickname, entry.command, entry.orderIndex,
        entry.accountInputRequired, entry.idInputRequired)
    );
    return true;
  }

  async updateEntriesOrder(entries: Array<CommandEntry>): Promise<boolean> {
    this.persisted = entries;
    if (this.persistFails) return false;

    for (const entry of entries) {
      for (const stored of this.store) {
        if (stored.id === entry.id) stored.orderIndex = entry.orderIndex;
      }
    }
    this.store.sort((a: CommandEntry, b: CommandEntry) => a.orderIndex - b.orderIndex);
    return true;
  }
}

function seed(): Array<CommandEntry> {
  return [
    new CommandEntry(1, 'a', 'status', 0, 0, 0),
    new CommandEntry(2, 'b', 'help', 1, 0, 0),
    new CommandEntry(3, 'c', 'stop', 2, 0, 0)
  ];
}

function nicknames(vm: CommandListViewModel): string {
  return vm.entries.map((item) => item.nickname).join(',');
}

/**
 * 应用设置端口替身：只在内存里记布局。
 * `writes` 用来观察「同值不写盘」，`writeFails` 用来注入落盘失败（设计 §2.1 的失败处置）。
 */
class FakeAppSettingsRepository implements AppSettingsRepository {
  storedLayout: ListLayout = ListLayout.SINGLE;
  writes: number = 0;
  writeFails: boolean = false;

  async get(): Promise<ColorMode> {
    return ColorMode.FOLLOW_SYSTEM;
  }

  async set(_mode: ColorMode): Promise<boolean> {
    return true;
  }

  async getLayout(): Promise<ListLayout> {
    return this.storedLayout;
  }

  async setLayout(layout: ListLayout): Promise<boolean> {
    this.writes++;
    if (this.writeFails) return false;

    this.storedLayout = layout;
    return true;
  }
}

export default function viewModelsTest() {
  describe('ViewModels', () => {
    // U13：拖拽排序成功 → 顺序更新并持久化
    it('movePersistsNewOrder', 0, async () => {
      const aggregate = new FakeAggregate(seed());
      const vm = new CommandListViewModel(aggregate);
      await vm.loadEntries();

      expect(vm.move(0, 2)).assertTrue();
      await settle();

      expect(aggregate.persisted.length).assertEqual(3);
      expect(aggregate.persisted[0].nickname).assertEqual('b');
      expect(aggregate.persisted[0].orderIndex).assertEqual(0);
      expect(aggregate.persisted[2].nickname).assertEqual('a');
      expect(aggregate.persisted[2].orderIndex).assertEqual(2);
      expect(nicknames(vm)).assertEqual('b,c,a');
    });

    // U14：拖拽排序持久化失败 → 顺序回滚为数据库顺序，并通知页面
    it('moveRollsBackWhenPersistFails', 0, async () => {
      const aggregate = new FakeAggregate(seed());
      aggregate.persistFails = true;

      const vm = new CommandListViewModel(aggregate);
      let notified = 0;
      vm.onMoveFailed = () => {
        notified++;
      };
      await vm.loadEntries();

      expect(vm.move(0, 2)).assertTrue();
      await settle();

      expect(nicknames(vm)).assertEqual('a,b,c');
      expect(notified).assertEqual(1);
    });
    // 搜索过滤下的拖拽：可见下标要映回全量位置，不能把另一条的顺序改掉（评审第 1 条的回归守卫）
    it('moveUnderFilterReordersVisibleEntries', 0, async () => {
      const aggregate = new FakeAggregate([
        new CommandEntry(1, 'one', 'status', 0, 0, 0),
        new CommandEntry(2, 'two', 'others', 1, 0, 0),
        new CommandEntry(3, 'three', 'status', 2, 0, 0),
        new CommandEntry(4, 'four', 'others', 3, 0, 0)
      ]);
      const vm = new CommandListViewModel(aggregate);
      await vm.loadEntries();
      vm.setKeyword('status');
      expect(nicknames(vm)).assertEqual('one,three');

      expect(vm.move(0, 1)).assertTrue();
      await settle();

      // 可见序换成 three,one；不可见的 two/four 相对顺序不变，退出的是「把 one 插到 three 之后」
      // （旧实现按可见下标 splice 全量，得到 two,one,three,four —— 动错了一条，本断言挡住它）
      expect(aggregate.persisted.map((entry) => entry.nickname).join(',')).assertEqual('two,three,one,four');
      expect(nicknames(vm)).assertEqual('three,one');
    });


    // U16：列表仓库读抛错 → VM 置 loadError，不把列表当空
    it('loadFailureSetsErrorState', 0, async () => {
      const aggregate = new FakeAggregate(seed());
      const vm = new CommandListViewModel(aggregate);

      await vm.loadEntries();
      expect(vm.entries.length).assertEqual(3);
      expect(vm.loadError).assertEqual('');

      aggregate.loadFails = true;
      await vm.loadEntries();

      expect(vm.loadError.length > 0).assertTrue();
      expect(vm.entries.length).assertEqual(3);
      expect(vm.isEmpty()).assertFalse();

      aggregate.loadFails = false;
      await vm.retryLoad();

      expect(vm.loadError).assertEqual('');
      expect(vm.entries.length).assertEqual(3);
    });

    // 布局：没连共享设置时读回单列（领域默认值，不是猜）
    it('listLayoutDefaultsToSingle', 0, async () => {
      const repo = new FakeAppSettingsRepository();
      repo.storedLayout = ListLayout.DOUBLE;

      const vm = new CommandListViewModel(new FakeAggregate(seed()), repo);

      expect(vm.listLayout).assertEqual(ListLayout.SINGLE);
    });

    // 布局：`loadLayout` 把已落盘的布局写进共享设置
    it('loadLayoutReadsStoredLayout', 0, async () => {
      const repo = new FakeAppSettingsRepository();
      repo.storedLayout = ListLayout.DOUBLE;

      const vm = new CommandListViewModel(new FakeAggregate(seed()), repo);
      const settings = new AppSettings(ColorMode.FOLLOW_SYSTEM);
      vm.attachSettings(settings);

      await vm.loadLayout();

      expect(settings.listLayout).assertEqual(ListLayout.DOUBLE);
      expect(vm.listLayout).assertEqual(ListLayout.DOUBLE);
    });

    // 布局：`setLayout` 先写共享设置（界面即时生效）再落盘
    it('setLayoutWritesThrough', 0, async () => {
      const repo = new FakeAppSettingsRepository();
      const vm = new CommandListViewModel(new FakeAggregate(seed()), repo);
      const settings = new AppSettings(ColorMode.FOLLOW_SYSTEM);
      vm.attachSettings(settings);

      await vm.setLayout(ListLayout.DOUBLE);

      expect(settings.listLayout).assertEqual(ListLayout.DOUBLE);
      expect(repo.storedLayout).assertEqual(ListLayout.DOUBLE);
      expect(repo.writes).assertEqual(1);
    });

    // 布局：同值不写盘
    it('setLayoutSkipsWhenUnchanged', 0, async () => {
      const repo = new FakeAppSettingsRepository();
      const vm = new CommandListViewModel(new FakeAggregate(seed()), repo);
      vm.attachSettings(new AppSettings(ColorMode.FOLLOW_SYSTEM));

      await vm.setLayout(ListLayout.SINGLE);

      expect(repo.writes).assertEqual(0);
      expect(vm.listLayout).assertEqual(ListLayout.SINGLE);
    });

    // 布局：两态互换，两次之后回到原态
    it('toggleLayoutSwapsBothWays', 0, async () => {
      const repo = new FakeAppSettingsRepository();
      const vm = new CommandListViewModel(new FakeAggregate(seed()), repo);
      const settings = new AppSettings(ColorMode.FOLLOW_SYSTEM);
      vm.attachSettings(settings);

      await vm.toggleLayout();
      expect(vm.listLayout).assertEqual(ListLayout.DOUBLE);
      expect(repo.storedLayout).assertEqual(ListLayout.DOUBLE);

      await vm.toggleLayout();
      expect(vm.listLayout).assertEqual(ListLayout.SINGLE);
      expect(repo.storedLayout).assertEqual(ListLayout.SINGLE);
    });

    // 布局：落盘失败不回滚界面（与 `selectColorMode` 同一条处置，设计 §2.1）
    it('setLayoutKeepsUiSwitchWhenPersistFails', 0, async () => {
      const repo = new FakeAppSettingsRepository();
      repo.writeFails = true;

      const vm = new CommandListViewModel(new FakeAggregate(seed()), repo);
      const settings = new AppSettings(ColorMode.FOLLOW_SYSTEM);
      vm.attachSettings(settings);

      await vm.setLayout(ListLayout.DOUBLE);

      expect(vm.listLayout).assertEqual(ListLayout.DOUBLE);
      expect(settings.listLayout).assertEqual(ListLayout.DOUBLE);
      expect(repo.storedLayout).assertEqual(ListLayout.SINGLE);
    });
  });
}
