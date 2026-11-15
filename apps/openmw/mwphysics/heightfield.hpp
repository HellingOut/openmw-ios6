#ifndef OPENMW_MWPHYSICS_HEIGHTFIELD_H
#define OPENMW_MWPHYSICS_HEIGHTFIELD_H

#include <osg/ref_ptr>

#include <LinearMath/btScalar.h>

#include <vector>

class btCollisionObject;
class btHeightfieldTerrainShape;

namespace osg
{
    class Object;
}

namespace MWPhysics
{
    class HeightField
    {
    public:
        HeightField(const float* heights, int x, int y, float triSize, float sqrtVerts, float minH, float maxH, const osg::Object* holdObject);
        ~HeightField();

        btCollisionObject* getCollisionObject();
        const btCollisionObject* getCollisionObject() const;
        const btHeightfieldTerrainShape* getShape() const;

    private:
        // Copy of the height data converted to btScalar, owned because the shape references it
        // directly (see the constructor for why the original float data cannot be used).
        std::vector<btScalar> mHeights;
        btHeightfieldTerrainShape* mShape;
        btCollisionObject* mCollisionObject;
        osg::ref_ptr<const osg::Object> mHoldObject;

        void operator=(const HeightField&);
        HeightField(const HeightField&);
    };
}

#endif
