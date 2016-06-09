import System.IO ( stdin, hGetContents )
import System.Environment ( getArgs, getProgName )
import System.Exit ( exitFailure, exitSuccess )

import LexCPP
import ParCPP
import SkelCPP
import PrintCPP
import AbsCPP

import TypeCheckerCPP
import InterpreterCPP
import ErrM

checkFile :: String -> IO ()
checkFile s = case pProgram (myLexer s) of
            Bad err  -> do putStrLn "SYNTAX ERROR"
                           putStrLn err
                           exitFailure
            Ok  tree -> case typecheck tree of
                          Bad err -> do putStrLn "TYPE ERROR"
                                        putStrLn err
                                        exitFailure
                          Ok _    -> interpret tree

main :: IO ()
main = do args <- getArgs
          case args of
            [file] -> readFile file >>= checkFile
            _      -> do putStrLn "Usage: icpp <target file>"
                         exitFailure
