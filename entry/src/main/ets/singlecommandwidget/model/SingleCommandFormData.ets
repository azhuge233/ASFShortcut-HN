export default class SingleCommandFormData {
    formID: string = '';
    isInitialized: boolean = false;
    isRunning: boolean = false;

    shortcutID: number | null = null;
    nickname: string | null = null;
    command: string | null = null;

    runResult: string = '';

    constructor(formID: string, isInitialized: boolean) {
        this.formID = formID;
        this.isInitialized = isInitialized;
    }
}