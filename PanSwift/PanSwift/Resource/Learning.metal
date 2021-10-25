//
//  Learning.metal
//  PanSwift
//
//  Created by Pan on 2021/10/15.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - 向量
void vectorTest() {
    /**
     booln
     charn
     shortn
     intn
     ucharn / ushortn / uintn
     halfn
     floatn
     
     n-->向量中的n表示维度, 最大为4
     */
    bool2 b2 = bool2(1, 2);
    /** f4 -->4个变量组成的4维向量*/
    float4 f4 = float4(1.0, 2.0, 3.0, 4.0);
    float f = f4[0]; // 类似数组

    /** 4维向量可以表示xyzw或者rgba*/
    float x = f4.x;
    float y = f4.y;
    float r = f4.r;
    
    /** 多个分量访问*/
    float4 c = float4(0, 0, 0, 0);
    c.xyzw = float4(1, 2, 3, 4); //
    c.xy = float2(6, 0);
    c.yzw = float3(7, 8, 9);
    /** Metal分量访问可以乱序, 注意!!!, 和GLSL不同, GLSL不可乱序 xyzw/rgba顺序是不可变的*/
    float4 d = c.wxyz; // d = [9, 6, 7, 8]
    /** xywz和rgba不可混用, 只可选其一*/
    float4 m = float4(4, 3, 2, 1);
//    m.xg = float2(0, 9) // error!! 不可以混用
    m.rg = float2(0, 9); // m = [0, 9, 2, 1]
}

// MARK: - 矩阵
void matrixTest() {
    /**
     halfxnm / floatnxm
     nxm 中 n m 分别指 矩阵的行数 和 列数 --> 最大 4 x 4 : 4行4列
     */
    
    float4x4 mix;
    mix[1] = float4(2.0f); // 矩阵第一行的值都是2
    mix[1] = float4(1, 2, 3, 4); // 矩阵第一行的值
    mix[0][0] = 3; // 矩阵第0行0列的值为3
}

// MARK: - 纹理 Texture 类型
void textureTest(){
    /** 纹理类型是一个句柄，指向一个 一维/二维/三维纹理数据。在函数中描述纹理对象的类型。*/
    /**
     枚举:
     sample：纹理对象可以被采样，采样器可将纹理读取出来，可读可写可采样 --> 使用最多

     read：不使用采样器，一个图形渲染函数或并行计算函数 可以读取纹理对象

     write：一个图形渲染函数或并行计算函数 可以向纹理对象写入数据。
     */
    enum class access { sample, read, write };
    
    /**
     texture1d<T, access a = access::sample> // 一维纹理
     texture2d<T, access a = access::sample> // 二维纹理
     texture3d<T, access a = access::sample> // 三维纹理
     
     T：数据类型 ，指定从纹理中 读取/写入 时的颜色类型。T可以是 half、float、int 等；
     access：读写方式(权限)
     */
}

/// 示例
/// - Parameter imgA: texture2d<float>: 2维纹理，类型float，访问权限 sample --> 默认权限就是 sample 可不写
/// - Parameter imgB: texture2d<float, access::read>: 类型 float，权限 read
/// - Parameter imgC: 权限 write
void foo(texture2d<float> imgA [[texture(0)]],
         texture2d<float, access::read> imgB [[texture(1)]],
         texture2d<float, access::write> imgC [[texture(2)]]) {
    // ...
}

// MARK: - 采样器类型 Samplers
/**
 采样器类型决定了如何对一个纹理进行采样操作。
 Metal框架中有一个对应着色器语言的采样器对象：MTLSamplerState, 此对象作为图像渲染着色器函数 or 并行计算函数的参数进行传递。
 */
 void samplersTest() {
    // 从纹理中采样时，纹理坐标是否归一化
    enum class coord { normalized, peixel };
    
    // 纹理采样过滤方式 - 放大/缩小
    enum class filter { nearest, linear };

    // 缩小过滤方式
    enum class min_filter { nearest, linear };

    // 放大过滤方式
    enum class mag_filter { nearest, linear };

    // 设置纹理 s t r 坐标的寻址模式 （str 即 xyz 环绕方式）
    enum class s_address { clapm_to_zero, clapm_to_edge, repeat, mirrored_repeat };
    enum class t_address { clapm_to_zero, clapm_to_edge, repeat, mirrored_repeat };
    enum class r_address { clapm_to_zero, clapm_to_edge, repeat, mirrored_repeat };

    // 设置所有纹理坐标的寻址模式
    enum class address { clapm_to_zero, clapm_to_edge, repeat, mirrored_repeat };

    // 设置纹理采样的 mipMap 过滤模式，如果是 none ，则只有一层纹理生效
    enum class mip_filter { none, nearest, linear };
}

void samplerSetup() {
    /** ⚠️在 Metal 中，初始化采样器必须使用 constexpr 修饰符声明 */
    constexpr sampler s(coord::pixel, address::clamp_to_zero, filter::linear);
    constexpr sampler a(coord::normalized);
    constexpr sampler b(address::repeat);
    constexpr sampler c(address::clamp_to_edge, filter::nearest);
}

// MARK: - 函数修饰符

/**
 kernel：表示该函数是一个数据并行计算着色函数。我们要高效并发运算就用它。它可以被分配在 一维/二维/三维 线程组中去执行；--> 使用他修饰的函数返回类型必须是 void

 vertex：顶点着色函数。为顶点数据流中的每个顶点数据执行一次，然后为每个顶点生成数据输出到绘制管线；

 fragment：片元着色函数，为片元数据流中的每个片元与其关联执行一次，然后将每个片元生成的颜色数据输出到绘制管线中；

 注意1：只有图形着色函数才能用 vertex/fragment 修饰。函数返回类型可以用来辨认出它是为顶点 or 为每个像素 做计算的。返回 void 也可以但是无意义，因为顶点/片元函数本就是为了计算出相应数据将数据传到绘制管线的。

 注意2：被函数修饰符修饰的函数不能再调用 '被修饰符修饰的函数'，否则编译失败。即：被函数修饰符修饰的函数们不能相互调用。

 例：kernel void func1 (...) {}; vertex float4 funcV1 (...) { func1(...) } --> 错误调用，无法编译

 注意2：特定函数修饰，普通函数随意。
 
 */

kernel void kernelTest() {
    // ...
}

// MARK: - 变量或参数的地址空间修饰符

/**
 地址空间修饰符：用来指定 一个函数 参数/变量 被分配在内存中的哪块区域。

 device：设备地址空间

 threadgroup：线程组地址空间

 constant：常量地址空间

 thread： thread 地址空间

 a、对于图形着色器函数，是指针或引用类型的参数必须定义为 device 或 const 地址空间

 b、对于并行计算着色函数，对于是指针或引用的参数，必须使用 device 或 threadgroup 或 constant 修饰。
 
 */


/**
 Device Address Space(设备地址空间): ---------------------------------------------------------
 
 指向设备内存（显存）池分配出来的缓存对象，它可以是可读也可以是可写的；一个缓存对象可以被声明成一个标量、向量、自定义结构体的指针或引用。
 */
void addressSpaceTest() {
    /** ⚠️纹理对象总是在设备地址空间分配内存，device 地址空间修饰符不必出现在纹理类型定义中。一个纹理对象的内容无法直接访问，Metal提供了读写纹理的内建函数。*/
    
    // an array of a float vector with 4 components
    device float4 *color;
    // 定义个结构体
    struct Foo {
        float a[3];
        int b[2];
    };
    // an array of Foo elements
    device Foo *my_info;
}

/**
 线程组地址空间 threadgroup: ---------------------------------------------------------
 
 用于为并行计算着色函数分配内存变量(在GPU里)，这些变量被一个线程组的所有线程共享。在线程组地址空间分配的变量不能被用于图形绘制着色函数。
 在并行计算着色函数中，在线程组地址空间分配的变量为一个线程组使用，生命周期和线程相同。
 */

kernel void threadgroupTest(threadgroup float *a [[ threadgroup(0) ]]) {
    // A float allocated in threadgroup address space
    threadgroup float x;
    // An array of 10 floats allocated in threadgroup address space
    threadgroup float b[10];
}

/**
 常量地址空间 constant: ---------------------------------------------------------
 
 指向的缓存对象也是从设备内存池分配存储，但是是只读的。
 在程序域的变量必须定义在常量地址空间并且在声明的时候初始化；用来初始化的值必须是编译时的常量。此变量的生命周期和程序一样，在程序中的并行计算着色函数or图形绘制着色函数调用，但 constant 的值会保持不变。

 ⚠️：常量地址空间的指针或引用可以作为函数的参数(constant修饰的常量可作为函数的参数)。向声明为常量的变量赋值会产生变异错误(代码示例中sampler)，声明为常量但没有赋予初始值也会产生变异错误(代码示例中a)。
 */

// 错误示例
constant float sampler[] = {1.0, 2.0, 3.0, 4.0};
// 对一个常量地址空间的变量进行修改会失败，因为它是只读的
//sampler[4] = {3, 3, 3, 3};// 编译失败

// 定义常量地址空间但不初始化赋值 --> 也编译失败
//const float a;// 编译失败

/**
 线程地址空间 thread: ---------------------------------------------------------
 
 指向每个线程准备的地址空间，这个线程的地址空间定义的变量在其他线程是不可见的，在图形绘制着色函数or并行计算着色函数中声明的变量可以使用 thread 地址空间分配。
 */

kernel void threadTest() {
    float x;
    thread float *p = &x;
}

// MARK: - 函数参数与变量

/**
 图形绘制/并行计算着色函数的输入/输出都需要通过参数传递 ( 除了常量地址空间变量和程序域中定义的采样器 外)。参数如下：

 device buffer：设备缓存 - 指向设备地址空间的任意数据类型的指针 or 引用

 constant buffer：常量缓存 - 指向常量地址空间的任意数据类型的指针 or 引用

 texture object：纹理对象

 sample object：采样器对象

 threadgroup：线程共享的缓存
 
 对于每个着色器函数来说，一个修饰符是必须指定的，它用来设定一个缓存、纹理、采样器的位置：

 device buffer / constant buffer --> [[buffer(index)]]

 texture --> [[texture(index)]]

 sample --> [[sampler(index)]]

 threadgroup buffer --> [[threadgroup(index)]]
 
 index：一个 unsigned integer 类型的值，表示一个缓存、纹理、采样器的位置(在函数参数索引表中的位置)。语法上讲，属性修饰符的声明位置应该位于参数变量名之后。
 */

/// 一个简单的并行计算着色函数 my_add ，它把两个设备地址空间的魂村 inA、inB 相加，把结果写入缓存 out。
kernel void my_add(device float4 *inA [[ buffer(0) ]],
                   device float4 *inB [[ buffer(1) ]],
                   device float4 *out [[ buffer(2) ]],
                   uint id [[ thread_position_in_grid ]]) {
    /**
     属性修饰符 “buffer(index)” 为着色函数参数设定了缓存的位置, inA：放在设备地址空间，缓存位置对应的是 buffer(0)这个ID
     thread_position_in_grid：用于表示当前节点，在多线程网格中的位置 --> 我们是无法知道当前在GPU的哪个运算单元里，thread_position_in_grid 知道，我们通过它获取即可。
     */
    out[id] = inA[id] + inB[id];
}

// MARK: - 内建变量属性修饰符

/**
 [[vertex_id]] -- 顶点ID标识符

 [[position]] -- 1、当前顶点信息(float4 - xyzw)  2、也可描述 片元在窗口的相对坐标：当前这个像素点在屏幕上的哪个位置

 [[point_size]] -- 点的大小

 [[color(m)]] -- 颜色，m 编译前要确定
 
 ⚠️[[stage_in]] -- 其实就是：顶点着色器输出经过光栅化生成的传给片元着色器的每个片元数据。
 顶点和片元着色函数都是有且仅有一个参数可以被声明为使用"stage_in"修饰符的。 stage_in可以修饰结构体，其结构体成员可以有多个，类型可以为一个整型/浮点型的标量/向量。
 */

struct MyFragmentOutput {
    // 三组颜色，要知道使用时取哪一个
    float4 color_f [[ color(0) ]];
    int4 color_i [[ color(1) ]];
    uint4 color_ui [[ color(2) ]];
};

fragment MyFragmentOutput my_gray_shader() {
    MyFragmentOutput output;
    output.color_f = float4(1.0, 2.0, 3.0, 1.0);
    return output;
}
