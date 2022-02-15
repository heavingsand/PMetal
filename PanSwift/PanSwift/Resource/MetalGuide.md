# MetalGuide

## 存储模式, 缓存模式, 可清除性
MTLResource有几个相关常量:
MTLCPUCacheMode(缓存模式): 缓存模式确定CPU如何映射资源. 有两个选项defaultCache和writeCombined, 默认缓存保证读取和写入操作按照预期顺序执行. writeCombined唯一时间是创建CPU写入但稍后读取和写入操作按预期顺序执行.
MTLStorageMode(存储模式): 定义资源的内存位置和访问权限. 如果资源是共享的,则CPU和GPU都可以访问它. 如果资源是私有的, 则是能GPU访问.
MTLPurgeableState(可清除性): 你不会想要在内存中保留所有这些对象, 所以你需要定制一个如何删除他们的计划. MTLPurgeableState允许您更改资源的状态. 你无需控制每个应用程序的可清除性. 如果你要在不更改其可清除性的情况下访问资源, 请将状态设置为keepCurrent. 如果你不希望从内存汇中丢弃资源, 则将状态设置为nonVolatile. 如果不在需要资源, 设置为volatile, 则可以从内存中删除资源, 但不会自动清除该资源, 确定资源完全不再需要后, 状态将设置为空.

## MPSUnaryImageKernel
MPSUnaryImageKernel 是由 MetalPerformanceShaders 提供的基础滤镜接口。代表着输入源只有一个图像，对图像进行处理。同样的还有 MPSBinaryImageKernel 代表着两个输入源。 MPS 默认提供了很多图像滤镜，如 MPSImageGaussianBlur，MPSImageHistogram 等等。
MPSUnaryImageKernel 提供如下两个接口，分别代表替代原先 texture 和输出到新 texture 的方法：
- encodeToCommandBuffer:inPlaceTexture:fallbackCopyAllocator:
- encodeToCommandBuffer:sourceTexture:destinationTexture:
这边新建一个 MPSImageLut 类继承 MPSUnaryImageKernel，同时实现上面的两个接口：

