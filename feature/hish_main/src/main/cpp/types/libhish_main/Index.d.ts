export type NapiVmOptions = {
  argsLines: string
  unixSocket: string
  qmpSocket: string
  supportJit: boolean
}

export const startVM: (options: NapiVmOptions) => boolean;
export const onData: (callback: (ArrayBuffer) => void) => void;
export const onShutdown: (callback: () => void) => void;
export const sendInput: (content: ArrayBuffer) => void;
export const checkPortUsed: (port: number) => boolean;
export const getImageInfo: (imagePath: string) => string;
export const getSnapshots: (imagePath: string) => string;
export const createSnapshot: (imagePath: string, snapshotName: string) => string;
export const applySnapshot: (imagePath: string, snapshotName: string) => string;
export const deleteSnapshot: (imagePath: string, snapshotName: string) => string;
export const optimizeImage: (imagePath: string, outputPath: string, mode: 'sparse' | 'prealloc' | 'cleanup' | 'optimize') => string;
