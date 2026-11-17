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
        // (see BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h), so the buffer
        // must hold btScalar elements, not float. Copying through static_cast<btScalar> is
        // what keeps the shape correct at either precision: with double-precision Bullet it
        // widens each height (reading the game's float array directly would make Bullet read
        // 8 bytes per vertex and step over every second height), and under the now-default
        // single-precision build the cast is a no-op.
        // Getting this wrong makes the collision mesh garbage: the player falls through all
        // terrain, and the degenerate "contacts" it produces can throw the actor far away.
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
