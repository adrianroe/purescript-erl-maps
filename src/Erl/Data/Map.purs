module Erl.Data.Map
  ( Map
  , alter
  , delete
  , difference
  , empty
  , filter
  , filterKeys
  , filterWithKey
  , fromFoldable
  , fromFoldableWith
  , fromFoldableWithIndex
  , insert
  , isEmpty
  , keys
  , lookup
  , mapWithKey
  , mapMaybe
  , mapMaybeWithKey
  , member
  , singleton
  , size
  , toUnfoldable
  , toUnfoldableUnordered
  , values
  , update
  ) where

import Prelude

import Data.Foldable (class Foldable, foldl, foldr)
import Data.FoldableWithIndex (class FoldableWithIndex, foldlWithIndex)
import Data.Function.Uncurried (Fn2, mkFn2)
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (class Traversable, sequenceDefault)
import Data.Tuple (Tuple(..))
import Erl.Data.List (List)

foreign import data Map :: Type -> Type -> Type

foreign import empty :: forall a b. Map a b

foreign import isEmpty :: forall a b. Map a b -> Boolean

foreign import size :: forall a b. Map a b -> Int

foreign import insert :: forall a b. a -> b -> Map a b -> Map a b

foreign import filterWithKeyImpl :: forall k v. (Fn2 k v Boolean) -> Map k v -> Map k v
filterWithKey pred = filterWithKeyImpl (mkFn2 pred)

singleton :: forall a b. a -> b -> Map a b
singleton a b = insert a b empty

foreign import lookupImpl :: forall a b z. z -> (b -> z) -> a -> Map a b -> z

lookup :: forall a b. a -> Map a b -> Maybe b
lookup = lookupImpl Nothing Just

foreign import mapImpl :: forall k a b. (a -> b) -> Map k a -> Map k b

instance functorMap :: Functor (Map a) where
  map f m = mapImpl f m

foreign import mapWithKeyImpl :: forall k a b. (Fn2 k a b) -> Map k a -> Map k b

mapWithKey :: forall k a b. (k -> a -> b) -> Map k a -> Map k b
mapWithKey f = mapWithKeyImpl (mkFn2 f)

-- | Applies a function to each value in a map, discarding entries where the
-- | function returns `Nothing`.
mapMaybe :: forall k a b. Ord k => (a -> Maybe b) -> Map k a -> Map k b
mapMaybe = mapMaybeWithKey <<< const

-- | Applies a function to each key/value pair in a map, discarding entries
-- | where the function returns Nothing.
mapMaybeWithKey :: forall k a b. (k -> a -> Maybe b) -> Map k a -> Map k b
mapMaybeWithKey f = fold (\k a acc -> maybe acc (\b -> insert k b acc) (f k a)) empty

foreign import member :: forall k a. k -> Map k a -> Boolean

foreign import difference :: forall k a b. Map k a -> Map k b -> Map k a

foreign import delete :: forall k a. k -> Map k a -> Map k a

foreign import values :: forall a b. Map a b -> List b

foreign import keys :: forall a b. Map a b -> List a

-- Folds taken from purescript-foreign-object

foreign import foldMImpl :: forall a b m z. (m -> (z -> m) -> m) -> (z -> a -> b -> m) -> m -> Map a b -> m

alter :: forall k v. (Maybe v -> Maybe v) -> k -> Map k v -> Map k v
alter f k m = case lookup k m of
  Nothing -> case f Nothing of
    Nothing -> m
    Just v -> insert k v m
  org -> maybe' (\_ -> delete k m) (\v -> insert k v m) $ f org

-- | Update or delete the value for a key in a map
update :: forall k v. Ord k => (v -> Maybe v) -> k -> Map k v -> Map k v
update f k m = alter (maybe Nothing f) k m

-- | Fold the keys and values of a map
fold :: forall a b z. (z -> a -> b -> z) -> z -> Map a b -> z
fold = foldMImpl ((#))

-- | Fold the keys and values of a map, accumulating values using some
-- | `Monoid`.
foldMap :: forall a b m. Monoid m => (a -> b -> m) -> Map a b -> m
foldMap f = fold (\acc k v -> f k v <> acc) mempty

-- | Fold the keys and values of a map, accumulating values and effects in
-- | some `Monad`.
foldM :: forall a b m z. Monad m => (z -> a -> b -> m z) -> z -> Map a b -> m z
foldM f z = foldMImpl bind f (pure z)

-- | Convert any foldable collection of key/value pairs to a map.
-- | On key collision, later values take precedence over earlier ones.
fromFoldable :: forall f k v. Ord k => Foldable f => f (Tuple k v) -> Map k v
fromFoldable = foldl (\m (Tuple k v) -> insert k v m) empty

-- | Convert any foldable collection of key/value pairs to a map.
-- | On key collision, the values are configurably combined.
fromFoldableWith :: forall f k v. Ord k => Foldable f => (v -> v -> v) -> f (Tuple k v) -> Map k v
fromFoldableWith f = foldl (\m (Tuple k v) -> alter (combine v) k m) empty where
  combine v (Just v') = Just $ f v v'
  combine v Nothing = Just v

-- | Convert any indexed foldable collection into a map.
fromFoldableWithIndex :: forall f k v. Ord k => FoldableWithIndex k f => f v -> Map k v
fromFoldableWithIndex = foldlWithIndex (\k m v -> insert k v m) empty

foreign import toUnfoldImpl :: forall k v. (Fn2 k v (Tuple k v)) -> Map k v -> List (Tuple k v)
foreign import toUnfoldableUnorderedImpl :: forall k v. (Fn2 k v (Tuple k v)) -> Map k v -> List (Tuple k v)
-- | Convert a map to an unfoldable structure of key/value pairs where the keys are in ascending order
toUnfoldable :: forall f k v. Unfoldable f => Map k v -> f (Tuple k v)
toUnfoldable = L.toUnfoldable <$> toUnfoldImpl (mkFn2 Tuple)

-- | Convert a map to an unfoldable structure of key/value pairs
toUnfoldableUnordered :: forall f k v. Unfoldable f => Map k v -> f (Tuple k v)
toUnfoldableUnordered = L.toUnfoldable <$> toUnfoldableUnorderedImpl (mkFn2 Tuple)

instance foldableMap :: Foldable (Map a) where
  foldr f z m = foldr f z (values m)
  foldl f = fold (\z _ -> f z)
  foldMap f = foldMap (const f)

instance foldableWithIndexMap :: FoldableWithIndex a (Map a) where
  foldrWithIndex f = fold (\b i a -> f i a b)
  foldlWithIndex f = fold (\b i a -> f i b a)
  foldMapWithIndex = foldMap

instance traversableMap :: Traversable (Map a) where
  traverse f ms = fold (\acc k v -> flip (insert k) <$> acc <*> f v) (pure empty) ms
  sequence = sequenceDefault

-- | Filter out those key/value pairs of a map for which a predicate
-- | on the key fails to hold.
filterKeys :: forall k. Ord k => (k -> Boolean) -> Map k ~> Map k
filterKeys predicate = filterWithKey $ const <<< predicate

-- | Filter out those key/value pairs of a map for which a predicate
-- | on the value fails to hold.
filter :: forall k v. Ord k => (v -> Boolean) -> Map k v -> Map k v
filter predicate = filterWithKey $ const predicate
