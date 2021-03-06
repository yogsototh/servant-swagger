{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE QuasiQuotes #-}
module Servant.SwaggerSpec where

import Control.Lens
import Data.Aeson
import qualified Data.Aeson.Types as JSON
import Data.Aeson.QQ
import Data.Char (toLower)
import Data.Proxy
import Data.Swagger
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time
import GHC.Generics
import Servant.API
import Servant.Swagger
import Test.Hspec

checkAPI :: HasSwagger api => Proxy api -> Value -> IO ()
checkAPI proxy = checkSwagger (toSwagger proxy)

checkSwagger :: Swagger -> Value -> IO ()
checkSwagger swag js = toJSON swag `shouldBe` js

spec :: Spec
spec = describe "HasSwagger" $ do
  it "Todo API" $ checkAPI (Proxy :: Proxy TodoAPI) todoAPI
  it "Hackage API (with tags)" $ checkSwagger hackageSwaggerWithTags hackageAPI

main :: IO ()
main = hspec spec

-- =======================================================================
-- Todo API
-- =======================================================================

data Todo = Todo
  { created     :: UTCTime
  , title       :: String
  , description :: Maybe String
  } deriving (Generic, FromJSON, ToSchema)

newtype TodoId = TodoId String deriving (Generic, ToParamSchema)

type TodoAPI = "todo" :> Capture "id" TodoId :> Get '[JSON] Todo

todoAPI :: Value
todoAPI = [aesonQQ|
{
  "swagger":"2.0",
  "info":
    {
      "title": "",
      "version": ""
    },
  "definitions":
    {
      "Todo":
        {
          "type": "object",
          "required": [ "created", "title" ],
          "properties":
            {
              "created": { "$ref": "#/definitions/UTCTime" },
              "title": { "type": "string" },
              "description": { "type": "string" }
            }
        },
      "UTCTime":
        {
          "type": "string",
          "format": "yyyy-mm-ddThh:MM:ssZ"
        }
    },
  "paths":
    {
      "/todo/{id}":
        {
          "get":
            {
              "responses":
                {
                  "200":
                    {
                      "schema": { "$ref":"#/definitions/Todo" },
                      "description": ""
                    },
                  "404": { "description": "id not found" }
                },
              "produces": [ "application/json" ],
              "parameters":
                [
                  {
                    "required": true,
                    "in": "path",
                    "name": "id",
                    "type": "string"
                   }
                ]
            }
        }
    }
}
|]

-- =======================================================================
-- Hackage API
-- =======================================================================

type HackageAPI
    = HackageUserAPI
 :<|> HackagePackagesAPI

type HackageUserAPI =
      "users" :> Get '[JSON] [UserSummary]
 :<|> "user" :> Capture "username" Username :> Get '[JSON] UserDetailed

type HackagePackagesAPI
    = "packages" :> Get '[JSON] [Package]

type Username = Text

data UserSummary = UserSummary
  { summaryUsername :: Username
  , summaryUserid   :: Int
  } deriving (Eq, Show, Generic)

lowerCutPrefix :: String -> String -> String
lowerCutPrefix s = map toLower . drop (length s)

instance ToJSON UserSummary where
  toJSON = genericToJSON JSON.defaultOptions { JSON.fieldLabelModifier = lowerCutPrefix "summary" }

instance ToSchema UserSummary where
  declareNamedSchema proxy = do
    (name, schema) <- genericDeclareNamedSchema defaultSchemaOptions { fieldLabelModifier = lowerCutPrefix "summary" } proxy
    return (name, schema
      & schemaExample ?~ toJSON UserSummary
         { summaryUsername = "JohnDoe"
         , summaryUserid   = 123 })

type Group = Text

data UserDetailed = UserDetailed
  { username :: Username
  , userid   :: Int
  , groups   :: [Group]
  } deriving (Eq, Show, Generic, ToSchema)

newtype Package = Package { packageName :: Text }
  deriving (Eq, Show, Generic, ToSchema)

hackageSwaggerWithTags :: Swagger
hackageSwaggerWithTags = toSwagger (Proxy :: Proxy HackageAPI)
  & host ?~ Host "hackage.haskell.org" Nothing
  & usersOps    %~ addTag "users"
  & packagesOps %~ addTag "packages"
  & tags .~
      [ Tag "users" (Just "Operations about user") Nothing
      , Tag "packages" (Just "Query packages") Nothing
      ]
  where
    usersOps    = subOperations (Proxy :: Proxy HackageUserAPI)     (Proxy :: Proxy HackageAPI)
    packagesOps = subOperations (Proxy :: Proxy HackagePackagesAPI) (Proxy :: Proxy HackageAPI)

hackageAPI :: Value
hackageAPI = [aesonQQ|
{
   "swagger":"2.0",
   "host":"hackage.haskell.org",
   "info":{
      "version":"",
      "title":""
   },
   "definitions":{
      "UserDetailed":{
         "required":[
            "username",
            "userid",
            "groups"
         ],
         "type":"object",
         "properties":{
            "groups":{
               "items":{
                  "type":"string"
               },
               "type":"array"
            },
            "username":{
               "type":"string"
            },
            "userid":{
               "maximum":9223372036854775807,
               "minimum":-9223372036854775808,
               "type":"integer"
            }
         }
      },
      "Package":{
         "required":[
            "packageName"
         ],
         "type":"object",
         "properties":{
            "packageName":{
               "type":"string"
            }
         }
      },
      "UserSummary":{
         "required":[
            "username",
            "userid"
         ],
         "type":"object",
         "properties":{
            "username":{
               "type":"string"
            },
            "userid":{
               "maximum":9223372036854775807,
               "minimum":-9223372036854775808,
               "type":"integer"
            }
         },
         "example":{
            "username": "JohnDoe",
            "userid": 123
         }
      }
   },
   "paths":{
      "/users":{
         "get":{
            "responses":{
               "200":{
                  "schema":{
                     "items":{
                        "$ref":"#/definitions/UserSummary"
                     },
                     "type":"array"
                  },
                  "description":""
               }
            },
            "produces":[
               "application/json"
            ],
            "tags":[
               "users"
            ]
         }
      },
      "/packages":{
         "get":{
            "responses":{
               "200":{
                  "schema":{
                     "items":{
                        "$ref":"#/definitions/Package"
                     },
                     "type":"array"
                  },
                  "description":""
               }
            },
            "produces":[
               "application/json"
            ],
            "tags":[
               "packages"
            ]
         }
      },
      "/user/{username}":{
         "get":{
            "responses":{
               "404":{
                  "description":"username not found"
               },
               "200":{
                  "schema":{
                     "$ref":"#/definitions/UserDetailed"
                  },
                  "description":""
               }
            },
            "produces":[
               "application/json"
            ],
            "parameters":[
               {
                  "required":true,
                  "in":"path",
                  "name":"username",
                  "type":"string"
               }
            ],
            "tags":[
               "users"
            ]
         }
      }
   },
   "tags":[
      {
         "name":"users",
         "description":"Operations about user"
      },
      {
         "name":"packages",
         "description":"Query packages"
      }
   ]
}
|]

