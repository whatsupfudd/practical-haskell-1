-- Create some Runtime parameters for neater main logic.

module Options.Runtime (RunOptions (..), WebServerOptions (..)) where

import Data.Text (Text)

import WebServer.CorsPolicy (CorsConfig, defaultCorsPolicy)

data WebServerOptions = WebServerOptions {
    port :: Int
    , host :: Text
  }
  deriving (Show)

data RunOptions = RunOptions {
    debug :: Int
    , webServer :: WebServerOptions
    , jwkConfFile :: Maybe FilePath
    , corsPolicy :: Maybe CorsConfig
  }
  deriving (Show)