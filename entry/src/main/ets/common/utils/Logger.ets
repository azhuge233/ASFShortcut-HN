import { hilog } from '@kit.PerformanceAnalysisKit';

class Logger {
    private domain: number;
    private prefix: string;
    private format: string = '%{public}s -> %{public}s';

    constructor(prefix: string) {
        this.prefix = prefix;
        this.domain = 0xFF00;
    }

    debug(...args: string[]) {
        hilog.debug(this.domain, this.prefix, this.format, args[0] ?? '', args[1] ?? '');
    }

    info(...args: string[]) {
        hilog.info(this.domain, this.prefix, this.format, args[0] ?? '', args[1] ?? '');
    }

    warn(...args: string[]) {
        hilog.warn(this.domain, this.prefix, this.format, args[0] ?? '', args[1] ?? '');
    }

    error(...args: string[]) {
        hilog.error(this.domain, this.prefix, this.format, args[0] ?? '', args[1] ?? '');
    }
}

export default new Logger('[ASFShortcut]');