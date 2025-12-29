export default class FormData {
    formID: string = '';
    isInitialized: boolean = false;

    shortcutID: number | null = null;
    nickname: string | null = null;
    command: string | null = null;

    constructor(formID: string, isInitialized: boolean) {
        this.formID = formID;
        this.isInitialized = isInitialized;
    }
}