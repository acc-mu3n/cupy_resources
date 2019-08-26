"""Thin wrapper of CUDA Runtime API.

There are four differences compared to the original C API.

1. Not all functions are ported.
2. Errors are translated into CUDARuntimeError exceptions.
3. The 'cuda' prefix of each API is omitted and the next character is set to
   lower case.
4. The resulting values are returned directly instead of references.

"""
cimport cpython  # NOQA
from cpython.mem cimport PyMem_Malloc, PyMem_Free  # NOQA
cimport cython  # NOQA

from cupy.cuda cimport driver


cdef class PointerAttributes:

    def __init__(self, int device, intptr_t devicePointer,
                 intptr_t hostPointer, int isManaged, int memoryType):
        self.device = device
        self.devicePointer = devicePointer
        self.hostPointer = hostPointer
        self.isManaged = isManaged
        self.memoryType = memoryType


cdef class ChannelFormatDescriptor:
    def __init__(self, int f, int w, int x, int y, int z):
        # We don't call cudaCreateChannelDesc here to avoid out of scope 
        self.ptr = <intptr_t>PyMem_Malloc(sizeof(ChannelFormatDesc))
        cdef ChannelFormatDesc desc = (<ChannelFormatDesc*>self.ptr)[0]
        desc.f = <ChannelFormatKind>f
        desc.w = w
        desc.x = x
        desc.y = y
        desc.z = z

    def __dealloc__(self):
        PyMem_Free(<ChannelFormatDesc*>self.ptr)
        self.ptr = 0

#    cdef ChannelFormatDesc* get_desc(self):
#        return self.ptr
##        cdef cudaChannelFormatDesc desc
##        desc.f = self.f
##        desc.w = self.w
##        desc.x = self.x
##        desc.y = self.y
##        desc.z = self.z
##        return desc

cdef class ResourceDescriptor:
    def __init__(self, int restype, array=None, intptr_t devPtr=0,
                 ChannelFormatDescriptor chDesc=None, sizeInBytes=None, width=None, height=None,
                 pitchInBytes=None):
        if resType == cudaResourceTypeMipmappedArray:
            # TODO(leofang): support this?
            raise NotImplementedError('cudaResourceTypeMipmappedArray is '
                                      'currently not supported.')

        cdef ResourceType resType = <ResourceType>restype
        self.ptr = <intptr_t>PyMem_Malloc(sizeof(ResourceDesc))
        cdef ResourceDesc desc = (<ResourceDesc*>self.ptr)[0]
        desc.resType = resType
        if resType == cudaResourceTypeArray:
            desc.res.array.array = <Array>array  # TODO: check this
        elif resType == cudaResourceTypeLinear:
            desc.res.linear.devPtr = <void*>devPtr
            desc.res.linear.desc = (<ChannelFormatDesc*>chDesc.ptr)[0]
            desc.res.linear.sizeInBytes = sizeInBytes
        elif resType == cudaResourceTypePitch2D:
            desc.res.pitch2D.devPtr = <void*>devPtr
            desc.res.pitch2D.desc = (<ChannelFormatDesc*>chDesc.ptr)[0]
            desc.res.pitch2D.width = width
            desc.res.pitch2D.height = height
            desc.res.pitch2D.pitchInBytes = pitchInBytes

    def __dealloc__(self):
        PyMem_Free(<ResourceDesc*>self.ptr)
        self.ptr = 0

#    cdef ResourceDesc get_cudaResourceDesc(self):
#        cdef ResourceDesc desc
#        resType = desc.resType = self.resType
#        if resType == cudaResourceTypeArray:
#            desc.array = self.array
#        elif resType == cudaResourceTypeLinear:
#            desc.devPtr = self.devPtr = devPtr
#            desc.desc = self.desc.get_cudaChannelFormatDesc()
#            desc.sizeInBytes = self.sizeInBytes
#        elif resType == cudaResourceTypePitch2D:
#            desc.devPtr = self.devPtr = devPtr
#            desc.desc = self.desc.get_cudaChannelFormatDesc()
#            desc.width = self.width
#            desc.height = self.height
#            desc.pitchInBytes = self.pitchInBytes
#        return desc

cdef class TextureDescriptor:
    def __init__(self, addressModes, int filterMode, int readMode,
                 sRGB=None, borderColors=None, normalizedCoords=None,
                 maxAnisotropy=None):
        self.ptr = <intptr_t>PyMem_Malloc(sizeof(TextureDesc))
        cdef TextureDesc desc = (<TextureDesc*>self.ptr)[0]
        for i, mode in enumerate(addressModes):
            desc.addressMode[i] = <TextureAddressMode>mode
        desc.filterMode = <TextureFilterMode>filterMode
        desc.readMode = <TextureReadMode>readMode
        if sRGB is not None:
            desc.sRGB = sRGB
        if borderColors is not None:
            for i, color in enumerate(borderColors):
                desc.borderColor[i] = color
        if normalizedCoords is not None:
            desc.normalizedCoords = normalizedCoords
        if maxAnisotropy is not None:
            desc.maxAnisotropy = maxAnisotropy

    def __dealloc__(self):
        PyMem_Free(<TextureDesc*>self.ptr)
        self.ptr = 0

#        for i, mode in enumerate(addressModes):
#            self.addressMode[i] = mode
#        self.filterMode = filterMode
#        self.readMode = readMode
#        if sRGB is not None:
#            self.sRGB = sRGB
#        if borderColors is not None:
#            assert len(borderColors) == 4
#            for i, color in enumerate(borderColors):            
#                self.borderColor[i] = color
#        if normalizedCoords is not None:
#            self.normalizedCoords = normalizedCoords
#        if maxAnisotropy is not None:
#            self.maxAnisotropy = maxAnisotropy
#
#    cdef TextureDesc get_cudaTextureDesc(self):
#        cdef cudaTextureDesc desc
#        for i, mode in enumerate(self.addressMode):
#            desc.addressMode = mode
#        desc.filterMode = self.filterMode
#        desc.readMode = self.readMode
#        if self.sRGB is not None:
#            desc.sRGB = self.sRGB
#        if borderColors is not None:
#            for i, color in enumerate(self.borderColor):
#                desc.borderColor[i] = color
#        if self.normalizedCoords is not None:
#            desc.normalizedCoords = self.normalizedCoords
#        if self.maxAnisotropy is not None:
#            desc.maxAnisotropy = self.maxAnisotropy


###############################################################################
# Extern
###############################################################################
cdef extern from *:
    ctypedef int DeviceAttr 'enum cudaDeviceAttr'
    ctypedef int MemoryAdvise 'enum cudaMemoryAdvise'
    ctypedef int MemoryKind 'enum cudaMemcpyKind'

    ctypedef void StreamCallbackDef(
        driver.Stream stream, Error status, void* userData)
    ctypedef StreamCallbackDef* StreamCallback 'cudaStreamCallback_t'


cdef extern from 'cupy_cuda.h' nogil:

    # Types
    struct _PointerAttributes 'cudaPointerAttributes':
        int device
        void* devicePointer
        void* hostPointer
        int isManaged
        int memoryType

    # Error handling
    const char* cudaGetErrorName(Error error)
    const char* cudaGetErrorString(Error error)
    int cudaGetLastError()

    # Initialization
    int cudaDriverGetVersion(int* driverVersion)
    int cudaRuntimeGetVersion(int* runtimeVersion)

    # Device operations
    int cudaGetDevice(int* device)
    int cudaDeviceGetAttribute(int* value, DeviceAttr attr, int device)
    int cudaGetDeviceCount(int* count)
    int cudaSetDevice(int device)
    int cudaDeviceSynchronize()

    int cudaDeviceCanAccessPeer(int* canAccessPeer, int device,
                                int peerDevice)
    int cudaDeviceEnablePeerAccess(int peerDevice, unsigned int flags)

    # Memory management
    int cudaMalloc(void** devPtr, size_t size)
    int cudaMallocManaged(void** devPtr, size_t size, unsigned int flags)
    int cudaMalloc3DArray(Array* array, const ChannelFormatDesc* desc,
                          Extent extent, unsigned int flags)
    int cudaMallocArray(Array* array, const ChannelFormatDesc* desc,
                        size_t width, size_t height, unsigned int flags)
    int cudaHostAlloc(void** ptr, size_t size, unsigned int flags)
    int cudaHostRegister(void *ptr, size_t size, unsigned int flags)
    int cudaHostUnregister(void *ptr)
    int cudaFree(void* devPtr)
    int cudaFreeHost(void* ptr)
    int cudaFreeArray(Array array)
    int cudaMemGetInfo(size_t* free, size_t* total)
    int cudaMemcpy(void* dst, const void* src, size_t count,
                   MemoryKind kind)
    int cudaMemcpyAsync(void* dst, const void* src, size_t count,
                        MemoryKind kind, driver.Stream stream)
    int cudaMemcpyPeer(void* dst, int dstDevice, const void* src,
                       int srcDevice, size_t count)
    int cudaMemcpyPeerAsync(void* dst, int dstDevice, const void* src,
                            int srcDevice, size_t count,
                            driver.Stream stream)
    int cudaMemcpy2DToArray(Array dst, size_t wOffset, size_t hOffset,
                            const void* src, size_t spitch, size_t width,
                            size_t height, MemoryKind kind)
    int cudaMemset(void* devPtr, int value, size_t count)
    int cudaMemsetAsync(void* devPtr, int value, size_t count,
                        driver.Stream stream)
    int cudaMemPrefetchAsync(const void *devPtr, size_t count, int dstDevice,
                             driver.Stream stream)
    int cudaMemAdvise(const void *devPtr, size_t count,
                      MemoryAdvise advice, int device)
    int cudaPointerGetAttributes(_PointerAttributes* attributes,
                                 const void* ptr)
    Extent make_cudaExtent(size_t w, size_t h, size_t d)

    # Stream and Event
    int cudaStreamCreate(driver.Stream* pStream)
    int cudaStreamCreateWithFlags(driver.Stream* pStream,
                                  unsigned int flags)
    int cudaStreamDestroy(driver.Stream stream)
    int cudaStreamSynchronize(driver.Stream stream)
    int cudaStreamAddCallback(driver.Stream stream, StreamCallback callback,
                              void* userData, unsigned int flags)
    int cudaStreamQuery(driver.Stream stream)
    int cudaStreamWaitEvent(driver.Stream stream, driver.Event event,
                            unsigned int flags)
    int cudaEventCreate(driver.Event* event)
    int cudaEventCreateWithFlags(driver.Event* event, unsigned int flags)
    int cudaEventDestroy(driver.Event event)
    int cudaEventElapsedTime(float* ms, driver.Event start,
                             driver.Event end)
    int cudaEventQuery(driver.Event event)
    int cudaEventRecord(driver.Event event, driver.Stream stream)
    int cudaEventSynchronize(driver.Event event)

    # Texture
    ChannelFormatDesc cudaCreateChannelDesc(int x, int y, int z, int w,
                                            ChannelFormatKind f)
    int cudaCreateTextureObject(TextureObject* pTexObject,
                                const ResourceDesc* pResDesc,
                                const TextureDesc* pTexDesc,
                                const ResourceViewDesc* pResViewDesc)
    int cudaDestroyTextureObject(TextureObject texObject)
    #int cudaGetChannelDesc(ChannelFormatDesc* desc, cudaArray_const_t array )
    #int cudaGetTextureObjectResourceDesc(ResourceDesc* pResDesc,
    #                                     TextureObject_t texObject)
    #int cudaGetTextureObjectResourceViewDesc ( cudaResourceViewDesc* pResViewDesc, cudaTextureObject_t texObject )
    #int cudaGetTextureObjectTextureDesc ( cudaTextureDesc* pTexDesc, cudaTextureObject_t texObject )


###############################################################################
# Error codes
###############################################################################

errorInvalidValue = cudaErrorInvalidValue
errorMemoryAllocation = cudaErrorMemoryAllocation


###############################################################################
# Error handling
###############################################################################

class CUDARuntimeError(RuntimeError):

    def __init__(self, status):
        self.status = status
        cdef bytes name = cudaGetErrorName(<Error>status)
        cdef bytes msg = cudaGetErrorString(<Error>status)
        super(CUDARuntimeError, self).__init__(
            '%s: %s' % (name.decode(), msg.decode()))

    def __reduce__(self):
        return (type(self), (self.status,))


@cython.profile(False)
cpdef inline check_status(int status):
    if status != 0:
        # to reset error status
        cudaGetLastError()
        raise CUDARuntimeError(status)


###############################################################################
# Initialization
###############################################################################

cpdef int driverGetVersion() except? -1:
    cdef int version
    status = cudaDriverGetVersion(&version)
    check_status(status)
    return version


cpdef int runtimeGetVersion() except? -1:
    cdef int version
    status = cudaRuntimeGetVersion(&version)
    check_status(status)
    return version


###############################################################################
# Device and context operations
###############################################################################

cpdef int getDevice() except? -1:
    cdef int device
    status = cudaGetDevice(&device)
    check_status(status)
    return device


cpdef int deviceGetAttribute(int attrib, int device) except? -1:
    cdef int ret
    status = cudaDeviceGetAttribute(&ret, <DeviceAttr>attrib, device)
    check_status(status)
    return ret


cpdef int getDeviceCount() except? -1:
    cdef int count
    status = cudaGetDeviceCount(&count)
    check_status(status)
    return count


cpdef setDevice(int device):
    status = cudaSetDevice(device)
    check_status(status)


cpdef deviceSynchronize():
    with nogil:
        status = cudaDeviceSynchronize()
    check_status(status)


cpdef int deviceCanAccessPeer(int device, int peerDevice) except? -1:
    cpdef int ret
    status = cudaDeviceCanAccessPeer(&ret, device, peerDevice)
    check_status(status)
    return ret


cpdef deviceEnablePeerAccess(int peerDevice):
    status = cudaDeviceEnablePeerAccess(peerDevice, 0)
    check_status(status)


###############################################################################
# Memory management
###############################################################################

cpdef intptr_t malloc(size_t size) except? 0:
    cdef void* ptr
    with nogil:
        status = cudaMalloc(&ptr, size)
    check_status(status)
    return <intptr_t>ptr


cpdef intptr_t mallocManaged(
        size_t size, unsigned int flags=cudaMemAttachGlobal) except? 0:
    cdef void* ptr
    with nogil:
        status = cudaMallocManaged(&ptr, size, flags)
    check_status(status)
    return <intptr_t>ptr


cpdef intptr_t malloc3DArray(size_t desc, size_t width, size_t height,
                             size_t depth, unsigned int flags = 0) except? 0:
    cdef Array ptr
    cdef Extent extent = make_cudaExtent(width, height, depth)
    with nogil:
        status = cudaMalloc3DArray(&ptr, <ChannelFormatDesc*>desc, extent,
                                   flags)
    check_status(status)
    return <intptr_t>ptr


cpdef intptr_t mallocArray(size_t desc, size_t width, size_t height,
                           unsigned int flags = 0) except? 0:
    cdef Array ptr
    with nogil:
        status = cudaMallocArray(&ptr, <ChannelFormatDesc*>desc, width,
                                 height, flags)
    check_status(status)
    return <intptr_t>ptr


cpdef intptr_t hostAlloc(size_t size, unsigned int flags) except? 0:
    cdef void* ptr
    with nogil:
        status = cudaHostAlloc(&ptr, size, flags)
    check_status(status)
    return <intptr_t>ptr


cpdef hostRegister(intptr_t ptr, size_t size, unsigned int flags):
    with nogil:
        status = cudaHostRegister(<void*>ptr, size, flags)
    check_status(status)


cpdef hostUnregister(intptr_t ptr):
    with nogil:
        status = cudaHostUnregister(<void*>ptr)
    check_status(status)


cpdef free(intptr_t ptr):
    with nogil:
        status = cudaFree(<void*>ptr)
    check_status(status)


cpdef freeHost(intptr_t ptr):
    with nogil:
        status = cudaFreeHost(<void*>ptr)
    check_status(status)


cpdef freeArray(intptr_t ptr):
    with nogil:
        status = cudaFreeArray(<Array>ptr)
    check_status(status)


cpdef memGetInfo():
    cdef size_t free, total
    status = cudaMemGetInfo(&free, &total)
    check_status(status)
    return free, total


cpdef memcpy(intptr_t dst, intptr_t src, size_t size, int kind):
    with nogil:
        status = cudaMemcpy(<void*>dst, <void*>src, size, <MemoryKind>kind)
    check_status(status)


cpdef memcpyAsync(intptr_t dst, intptr_t src, size_t size, int kind,
                  size_t stream):
    with nogil:
        status = cudaMemcpyAsync(
            <void*>dst, <void*>src, size, <MemoryKind>kind,
            <driver.Stream>stream)
    check_status(status)


cpdef memcpyPeer(intptr_t dst, int dstDevice, intptr_t src, int srcDevice,
                 size_t size):
    with nogil:
        status = cudaMemcpyPeer(<void*>dst, dstDevice, <void*>src, srcDevice,
                                size)
    check_status(status)


cpdef memcpyPeerAsync(intptr_t dst, int dstDevice, intptr_t src, int srcDevice,
                      size_t size, size_t stream):
    with nogil:
        status = cudaMemcpyPeerAsync(<void*>dst, dstDevice, <void*>src,
                                     srcDevice, size, <driver.Stream> stream)
    check_status(status)


cpdef memcpy2DToArray(intptr_t dst, size_t wOffset, size_t hOffset,
                      intptr_t src, size_t spitch, size_t width, size_t height,
                      int kind):
    with nogil:
        status = cudaMemcpy2DToArray(<Array>dst, wOffset, hOffset, <void*>src,
                                     spitch, width, height, <MemoryKind>kind)
    check_status(status)


cpdef memset(intptr_t ptr, int value, size_t size):
    with nogil:
        status = cudaMemset(<void*>ptr, value, size)
    check_status(status)


cpdef memsetAsync(intptr_t ptr, int value, size_t size, size_t stream):
    with nogil:
        status = cudaMemsetAsync(<void*>ptr, value, size,
                                 <driver.Stream> stream)
    check_status(status)

cpdef memPrefetchAsync(intptr_t devPtr, size_t count, int dstDevice,
                       size_t stream):
    with nogil:
        status = cudaMemPrefetchAsync(<void*>devPtr, count, dstDevice,
                                      <driver.Stream> stream)
    check_status(status)

cpdef memAdvise(intptr_t devPtr, size_t count, int advice, int device):
    with nogil:
        status = cudaMemAdvise(<void*>devPtr, count,
                               <MemoryAdvise>advice, device)
    check_status(status)


cpdef PointerAttributes pointerGetAttributes(intptr_t ptr):
    cdef _PointerAttributes attrs
    status = cudaPointerGetAttributes(&attrs, <void*>ptr)
    check_status(status)
    return PointerAttributes(
        attrs.device,
        <intptr_t>attrs.devicePointer,
        <intptr_t>attrs.hostPointer,
        attrs.isManaged, attrs.memoryType)


###############################################################################
# Stream and Event
###############################################################################

cpdef size_t streamCreate() except? 0:
    cdef driver.Stream stream
    status = cudaStreamCreate(&stream)
    check_status(status)
    return <size_t>stream


cpdef size_t streamCreateWithFlags(unsigned int flags) except? 0:
    cdef driver.Stream stream
    status = cudaStreamCreateWithFlags(&stream, flags)
    check_status(status)
    return <size_t>stream


cpdef streamDestroy(size_t stream):
    status = cudaStreamDestroy(<driver.Stream>stream)
    check_status(status)


cpdef streamSynchronize(size_t stream):
    with nogil:
        status = cudaStreamSynchronize(<driver.Stream>stream)
    check_status(status)


cdef _streamCallbackFunc(driver.Stream hStream, int status,
                         void* func_arg) with gil:
    obj = <object>func_arg
    func, arg = obj
    func(<size_t>hStream, status, arg)
    cpython.Py_DECREF(obj)


cpdef streamAddCallback(size_t stream, callback, intptr_t arg,
                        unsigned int flags=0):
    func_arg = (callback, arg)
    cpython.Py_INCREF(func_arg)
    with nogil:
        status = cudaStreamAddCallback(
            <driver.Stream>stream, <StreamCallback>_streamCallbackFunc,
            <void*>func_arg, flags)
    check_status(status)


cpdef streamQuery(size_t stream):
    return cudaStreamQuery(<driver.Stream>stream)


cpdef streamWaitEvent(size_t stream, size_t event, unsigned int flags=0):
    with nogil:
        status = cudaStreamWaitEvent(<driver.Stream>stream,
                                     <driver.Event>event, flags)
    check_status(status)


cpdef size_t eventCreate() except? 0:
    cdef driver.Event event
    status = cudaEventCreate(&event)
    check_status(status)
    return <size_t>event

cpdef size_t eventCreateWithFlags(unsigned int flags) except? 0:
    cdef driver.Event event
    status = cudaEventCreateWithFlags(&event, flags)
    check_status(status)
    return <size_t>event


cpdef eventDestroy(size_t event):
    status = cudaEventDestroy(<driver.Event>event)
    check_status(status)


cpdef float eventElapsedTime(size_t start, size_t end) except? 0:
    cdef float ms
    status = cudaEventElapsedTime(&ms, <driver.Event>start, <driver.Event>end)
    check_status(status)
    return ms


cpdef eventQuery(size_t event):
    return cudaEventQuery(<driver.Event>event)


cpdef eventRecord(size_t event, size_t stream):
    status = cudaEventRecord(<driver.Event>event, <driver.Stream>stream)
    check_status(status)


cpdef eventSynchronize(size_t event):
    with nogil:
        status = cudaEventSynchronize(<driver.Event>event)
    check_status(status)


##############################################################################
# util
##############################################################################

cdef int _context_initialized = cpython.PyThread_create_key()


cdef _ensure_context():
    """Ensure that CUcontext bound to the calling host thread exists.

    See discussion on https://github.com/cupy/cupy/issues/72 for details.
    """
    cdef size_t status
    status = <size_t>cpython.PyThread_get_key_value(_context_initialized)
    if status == 0:
        # Call Runtime API to establish context on this host thread.
        memGetInfo()
        cpython.PyThread_set_key_value(_context_initialized, <void *>1)


##############################################################################
# Texture
##############################################################################

cpdef createChannelDesc(int x, int y, int z, int w, ChannelFormatKind f):
    # we don't call this, as this seems to live on the stack?
    cdef ChannelFormatDesc desc
    with nogil:
        desc = cudaCreateChannelDesc(x, y, z, w, f)
    return desc

cpdef createTextureObject(ResourceDescriptor ResDesc,
                          TextureDescriptor TexDesc):
    cdef TextureObject texobj
    with nogil:
        status = cudaCreateTextureObject(&texobj, <ResourceDesc*>ResDesc.ptr,
                                         <TextureDesc*>TexDesc.ptr,
                                         <ResourceViewDesc*>NULL)
    check_status(status)
    return texobj

cpdef destroyTextureObject(TextureObject texObject):
    with nogil:
        status = cudaDestroyTextureObject(texObject)
    check_status(status)
