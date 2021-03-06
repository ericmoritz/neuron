{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Neuron.Config.Alias where

import Control.Monad.Except (liftEither, runExcept, throwError)
import Data.List (delete)
import Neuron.Config.Type
import qualified Neuron.Zettelkasten.Graph as G
import Neuron.Zettelkasten.Graph.Type (ZettelGraph)
import Neuron.Zettelkasten.ID
import Relude
import qualified Text.Megaparsec.Char as M
import Text.Megaparsec.Simple

data Alias = Alias
  { aliasZettel :: ZettelID,
    targetZettel :: ZettelID
  }
  deriving (Eq, Show)

getAliases :: MonadFail m => Config -> ZettelGraph -> m [Alias]
getAliases Config {..} graph = do
  let aliasSpecs = case aliases of
        -- In the absence of an index zettel, create an an alias to the z-index
        [] -> bool ["index:z-index"] [] $ hasIndexZettel graph
        as -> as
  case mkAliases aliasSpecs graph of
    Left err ->
      fail $ "Bad aliases in config: " <> toString err
    Right v ->
      pure v
  where
    hasIndexZettel =
      isJust . G.getZettel indexZid

mkAliases :: [Text] -> ZettelGraph -> Either Text [Alias]
mkAliases aliasSpecs graph =
  sequence $
    flip fmap aliasSpecs $ \aliasSpec -> runExcept $ do
      alias@Alias {..} <- liftEither $ parse aliasParser configFile aliasSpec
      when (isJust $ G.getZettel aliasZettel graph) $ do
        throwError $
          "Cannot create redirect from '" <> zettelIDRaw aliasZettel <> "', because a zettel with that ID already exists"
      when (zettelIDSlug targetZettel /= "z-index" && isNothing (G.getZettel targetZettel graph)) $ do
        throwError $
          "Target zettel '" <> zettelIDRaw targetZettel <> "' does not exist"
      pure alias

aliasParser :: Parser Alias
aliasParser =
  -- Disallow ':' in IDs, because we use colon as a separator in alias spec.
  -- TODO: Do proper parsing so colon is allowed in both IDs.
  let idParserSansColon = idParser' $ delete ':' allowedSpecialChars
   in Alias <$> (idParserSansColon <* M.char ':') <*> idParser
