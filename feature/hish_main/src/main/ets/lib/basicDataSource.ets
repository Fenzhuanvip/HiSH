/**
 * 通用 LazyForEach 数据源：实现 IDataSource，支持整体替换数据。
 * 用于大列表虚拟化，避免 ForEach 全量渲染带来的卡顿与内存占用。
 */
export class BasicDataSource<T> implements IDataSource {
  private listeners: DataChangeListener[] = []
  private data: T[] = []

  totalCount(): number {
    return this.data.length
  }

  getData(index: number): T {
    return this.data[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener)
    if (pos >= 0) {
      this.listeners.splice(pos, 1)
    }
  }

  /** 整体替换数据（用于列表刷新） */
  setData(list: T[]): void {
    this.data = list
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded())
  }
}