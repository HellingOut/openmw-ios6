#include "heightfield.hpp"

#include <osg/Object>

#include <BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h>
#include <BulletCollision/CollisionDispatch/btCollisionObject.h>

#include <LinearMath/btTransform.h>

namespace MWPhysics
{
    HeightField::HeightField(const float* heights, int x, int y, float triSize, float sqrtVerts, float minH, float maxH, const osg::Object* holdObject)
    {
        // btHeightfieldTerrainShape reads PHY_FLOAT height data through a `const btScalar*`
        // (see BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h). When Bullet is built with
        // BT_USE_DOUBLE_PRECISION, btScalar is double, so passing the game's float array makes Bullet read
        // 8 bytes per vertex and step over every second height: the collision mesh becomes garbage, the
        // player falls through the terrain, and degenerate "contacts" can throw the actor far away.
        // Convert the data to btScalar first (a no-op when Bullet is built single-precision).
        const int numVerts = static_cast<int>(sqrtVerts) * static_cast<int>(sqrtVerts);
        mHeights.resize(numVerts);
        for (int i = 0; i < numVerts; ++i)
            mHeights[i] = static_cast<btScalar>(heights[i]);

        mShape = new btHeightfieldTerrainShape(
            sqrtVerts, sqrtVerts, &mHeights[0], 1,
            minH, maxH, 2,
            PHY_FLOAT, false
        );
        mShape->setUseDiamondSubdivision(true);
        mShape->setLocalScaling(btVector3(triSize, triSize, 1));

        btTransform transform(btQuaternion::getIdentity(),
                                btVector3((x+0.5f) * triSize * (sqrtVerts-1),
                                          (y+0.5f) * triSize * (sqrtVerts-1),
                                          (maxH+minH)*0.5f));

        mCollisionObject = new btCollisionObject;
        mCollisionObject->setCollisionShape(mShape);
        mCollisionObject->setWorldTransform(transform);

        mHoldObject = holdObject;
    }

    HeightField::~HeightField()
    {
        delete mCollisionObject;
        delete mShape;
    }

    btCollisionObject* HeightField::getCollisionObject()
    {
        return mCollisionObject;
    }

    const btCollisionObject* HeightField::getCollisionObject() const
    {
        return mCollisionObject;
    }

    const btHeightfieldTerrainShape* HeightField::getShape() const
    {
        return mShape;
    }
}
