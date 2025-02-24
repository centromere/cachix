{-# LANGUAGE DuplicateRecordFields #-}

module Cachix.Deploy.Agent where

import qualified Cachix.API.WebSocketSubprotocol as WSS
import qualified Cachix.Client.OptionsParser as CachixOptions
import Cachix.Client.URI (getBaseUrl)
import qualified Cachix.Deploy.OptionsParser as AgentOptions
import Cachix.Deploy.StdinProcess (readProcess)
import qualified Cachix.Deploy.Websocket as CachixWebsocket
import qualified Data.Aeson as Aeson
import qualified Katip as K
import qualified Network.WebSockets as WS
import Paths_cachix (getBinDir)
import Protolude hiding (toS)
import Protolude.Conv
import qualified Servant.Client as Servant

run :: CachixOptions.CachixOptions -> AgentOptions.AgentOptions -> IO ()
run cachixOptions agentOpts = do
  CachixWebsocket.runForever options handleMessage
  where
    host = toS $ Servant.baseUrlHost $ getBaseUrl $ CachixOptions.host cachixOptions
    name = AgentOptions.name agentOpts
    options =
      CachixWebsocket.Options
        { CachixWebsocket.host = host,
          CachixWebsocket.name = name,
          CachixWebsocket.path = "/ws",
          CachixWebsocket.profile = AgentOptions.profile agentOpts,
          CachixWebsocket.isVerbose = CachixOptions.verbose cachixOptions
        }
    handleMessage :: ByteString -> (K.KatipContextT IO () -> IO ()) -> WS.Connection -> CachixWebsocket.AgentState -> ByteString -> K.KatipContextT IO ()
    handleMessage payload _ _ agentState _ = do
      CachixWebsocket.parseMessage payload (handleCommand . WSS.command)
      where
        handleCommand :: WSS.BackendCommand -> K.KatipContextT IO ()
        handleCommand (WSS.AgentRegistered agentInformation) = do
          CachixWebsocket.registerAgent agentState agentInformation
        handleCommand (WSS.Deployment deploymentDetails) = do
          -- TODO: lock to ensure one deployment at the time
          let input =
                CachixWebsocket.Input
                  { deploymentDetails = deploymentDetails,
                    websocketOptions =
                      CachixWebsocket.Options
                        { host = host,
                          name = name,
                          path = "/ws-deployment",
                          profile = AgentOptions.profile agentOpts,
                          isVerbose = CachixOptions.verbose cachixOptions
                        }
                  }
          binDir <- toS <$> liftIO getBinDir
          liftIO $ readProcess (binDir <> "/.cachix-deployment") [] (toS $ Aeson.encode input)
