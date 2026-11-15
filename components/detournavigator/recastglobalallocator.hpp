#ifndef OPENMW_COMPONENTS_DETOURNAVIGATOR_RECASTGLOBALALLOCATOR_H
#define OPENMW_COMPONENTS_DETOURNAVIGATOR_RECASTGLOBALALLOCATOR_H

#include "recasttempallocator.hpp"

#if defined(__IPHONEOS__)
#include <pthread.h>
#endif

namespace DetourNavigator
{
    class RecastGlobalAllocator
    {
    public:
        static void init()
        {
            instance();
        }

        static void* alloc(size_t size, rcAllocHint hint)
        {
            void* result = nullptr;
            if (rcLikely(hint == RC_ALLOC_TEMP))
                result = tempAllocator().alloc(size);
            if (rcUnlikely(!result))
                result = allocPerm(size);
            return result;
        }

        static void free(void* ptr)
        {
            if (rcUnlikely(!ptr))
                return;
            if (rcLikely(BufferType_temp == getDataPtrBufferType(ptr)))
                tempAllocator().free(ptr);
            else
            {
                assert(BufferType_perm == getDataPtrBufferType(ptr));
                ::free(getPermDataPtrHeapPtr(ptr));
            }
        }

    private:
        RecastGlobalAllocator()
        {
            rcAllocSetCustom(&RecastGlobalAllocator::alloc, &RecastGlobalAllocator::free);
        }

        static RecastGlobalAllocator& instance()
        {
            static RecastGlobalAllocator value;
            return value;
        }

        static RecastTempAllocator& tempAllocator()
        {
#if defined(__IPHONEOS__)
            // iOS 6 has no thread_local support.  Recast requires a per-thread
            // temporary allocator, so emulate it with a pthread key.
            static pthread_key_t key;
            static pthread_once_t once = PTHREAD_ONCE_INIT;
            pthread_once(&once, []() {
                pthread_key_create(&key, [](void* ptr) {
                    delete static_cast<RecastTempAllocator*>(ptr);
                });
            });
            void* value = pthread_getspecific(key);
            if (value == nullptr)
            {
                value = new RecastTempAllocator(1024ul * 1024ul);
                pthread_setspecific(key, value);
            }
            return *static_cast<RecastTempAllocator*>(value);
#else
            static thread_local RecastTempAllocator value(1024ul * 1024ul);
            return value;
#endif
        }

        static void* allocPerm(size_t size)
        {
            const auto ptr = ::malloc(size + sizeof(std::size_t));
            if (rcUnlikely(!ptr))
                return ptr;
            setPermPtrBufferType(ptr, BufferType_perm);
            return getPermPtrDataPtr(ptr);
        }
    };
}

#endif
