-- * Compiler cnstruction exercise 3 - Type Checker
-- * Definition of a type checker for a C++ subset defined in ../CPP.cf
-- * Textual description available at http://www1.digitalgrammars.com/ipl-book/assignments/assignment2/assignment2.html
-- * Authors
-- *
-- *   - Ruslan Tumarkin
-- *   - Benno Lauther
-- * 
-- * TODO: Extend Environment by function definitions à la "Id [Type] Type" in first run
-- * TODO: Typecheck each function in the resulting Environment

module TypeCheckerCPP where

import Debug.Trace
import PrintCPP
import AbsCPP
import ErrM

type Result = Err String


-- Entry point to typecheck a program
typecheck   :: Program -> Err ()
typecheck (PDefs definitions) = 
  do
  -- Step 1: Add all function definitions to the environment
    environMentWithDefinitions <- addDefinitions emptyEnvironment definitions
  -- Step 2: Check the definitions
    checkDefinitions environMentWithDefinitions definitions


-- Adds a list of function definitions to the environment
addDefinitions :: Environment -> [Def] -> Err Environment
addDefinitions environment [] = Ok environment
addDefinitions environment (currentDef: rest) = 
  do 
    newEnvironment <- addDefinition environment currentDef
    addDefinitions newEnvironment rest

-- Adds a single function definition to the environment
addDefinition :: Environment -> Def -> Err Environment
addDefinition environment definition = addFunctionDefinitionToEnvironment environment definition


-- Checks a list of functions definitions 
checkDefinitions :: Environment -> [Def] -> Err ()
checkDefinitions environment [] = return ()
checkDefinitions environment (currentDef: rest) =
  do 
    trace("Checking definition " ++ show currentDef) (checkDefinition environment currentDef)
    checkDefinitions environment rest

checkDefinition :: Environment -> Def -> Err ()
checkDefinition environment (DFun returnType id arguments statements) = 
  do
    -- Add extend new scope by arguments
    newEnvironment <- addArgumentsToEnvironment (addScope environment) arguments
    -- Check the statements in the environment
    checkStatements newEnvironment statements

-- Checks a list of statements 
checkStatements :: Environment -> [Stm] -> Err ()
checkStatements environment [] = return ()
checkStatements environment (statement:rest) = 
  do  
    newEnvironment <-  trace("Checking statement " ++ show statement) (checkStatement environment statement)
    checkStatements newEnvironment rest

checkStatement  :: Environment -> Stm -> Err Environment
checkStatement environment statement  = 
  case statement of
      SExp exp                -> 
        case inferExpression environment exp of
          Ok _ ->  Ok environment

      SDecls t ids            -> 
        do 
          addIdentifiers environment ids (VariableType t) -- add variables to environment
      SInit t id exp          -> 
        do
          newEnv <- addIdentifier environment id (VariableType t)
          t2 <- inferExpression newEnv exp
          if t /= t2
            then fail ("Cannot init variable " ++ printTree id ++ " of type " ++ printTree t ++ " with " ++ printTree exp)
          else return newEnv
      SReturn exp             -> fail "Not yet implemented"
      SReturnVoid             -> fail "Not yet implemented"
      SWhile exp stm          -> fail "Not yet implemented"
      SBlock stms             -> 
        do 
          checkStatements (addScope environment) stms
          return environment
      SIfElse exp stm1 stm2   -> fail "Not yet implemented"


checkExpression :: Environment -> Exp -> Type -> Err ()
checkExpression environment expression t = 
  do  
    newType <- inferExpression environment expression
    if newType /= t
      then fail (printTree expression ++ " has type " ++ printTree newType ++ " expected " ++ printTree t)
      else return ()




-- Ensures two expressions are of equal type
-- Results in an expression of the type of the first expression
ensureExpressionsHaveEqualTypes :: Environment -> Exp -> Exp -> Err Type 
ensureExpressionsHaveEqualTypes environment e1 e2 = 
  do
    e1Type <- inferExpression environment e1 
    e2Type <- inferExpression environment e2 
    if e1Type == e2Type 
      then return e1Type
      else failOperandTypesNotEqual e1 e1Type e2 e2Type


-- Ensures two expressions are of equal type
-- Results in an expression of type finalType
ensureEqualTypesReturnResultType :: Environment -> Exp -> Exp -> Type -> Err Type
ensureEqualTypesReturnResultType environment e1 e2 finalType =
  do
    e1Type <- inferExpression environment e1 
    e2Type <- inferExpression environment e2 
    if e1Type == e2Type 
      then return finalType
      else failOperandTypesNotEqual e1 e1Type e2 e2Type

inferExpression :: Environment -> Exp -> Err Type 
inferExpression environment expression = 
  case expression of
    ETrue               -> return Type_bool
    EFalse              -> return Type_bool
    EInt _              -> return Type_int
    EDouble _           -> return Type_double
    EString _           -> return Type_string
    EId id              -> 
      case lookupIdentifier environment id of
          Ok (VariableType t)   -> return t
          Ok (FunctionType _ returnType)  -> return returnType
    EApp id expressions -> fail "Not yet implemented"
    EPIncr expression   -> inferExpression environment expression
    EPDecr expression   -> inferExpression environment expression
    EIncr expression    -> inferExpression environment expression
    EDecr expression    -> inferExpression environment expression
    ETimes e1 e2        -> ensureExpressionsHaveEqualTypes environment e1 e2
    EDiv e1 e2          -> ensureExpressionsHaveEqualTypes environment e1 e2
    EPlus e1 e2         -> ensureExpressionsHaveEqualTypes environment e1 e2
    EMinus e1 e2        -> ensureExpressionsHaveEqualTypes environment e1 e2
    ELt e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EGt e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    ELtEq e1 e2         -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EGtEq e1 e2         -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EEq e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    ENEq e1 e2          -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EAnd e1 e2          -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EOr e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EAss e1 e2          -> ensureExpressionsHaveEqualTypes environment e1 e2
    ETyped expression t -> fail "Not yet implemented"



failOperandTypesNotEqual:: Exp -> Type -> Exp -> Type -> Err Type
failOperandTypesNotEqual e1 t1 e2 t2 = 
  fail (printTree e1 ++ " has type " ++ printTree t1 ++ " but " ++ printTree e2 ++ " has type " ++ printTree t2)

failure :: Show a => a -> Result
failure x = Bad $ "Undefined case: " ++ show x

data EnvironmentEntryType 
  = VariableType Type 
  | FunctionType [Type] Type

type Environment = [[(Id, EnvironmentEntryType)]] -- List of list of ids+types
emptyEnvironment :: Environment
emptyEnvironment = [[]]



addFunctionDefinitionToEnvironment :: Environment -> Def -> Err Environment
addFunctionDefinitionToEnvironment environment (DFun returnType identifier arguments _) = 
    addIdentifier environment identifier (FunctionType (map (\(ADecl argType _) -> argType) arguments) returnType)

addArgumentsToEnvironment :: Environment -> [Arg] -> Err Environment
addArgumentsToEnvironment environment [] = Ok environment
addArgumentsToEnvironment environment ((ADecl t id):rest) =
  do 
    newEnvironment <- addIdentifier environment id (VariableType t)
    addArgumentsToEnvironment newEnvironment rest

addIdentifiers :: Environment -> [Id] -> EnvironmentEntryType -> Err Environment
addIdentifiers environment [] _ = Ok environment
addIdentifiers environment (currentId:rest) t = 
  case addIdentifier environment currentId t of
    Ok  newEnvironment -> addIdentifiers newEnvironment rest t


addIdentifier :: Environment -> Id -> EnvironmentEntryType -> Err Environment
addIdentifier (scope:rest) id t = 
    case lookup id scope of
      Nothing -> return (((id, t):scope):rest)
      Just t  -> case t of
        VariableType _  -> fail ("Variable " ++ printTree id ++ " already declared.")
        FunctionType _ _  -> fail ("Function " ++ printTree id ++ " already declared.")

lookupIdentifier :: Environment -> Id -> Err EnvironmentEntryType
lookupIdentifier [] id = fail $ "Unknown identifier " ++ printTree id ++ "."
lookupIdentifier (scope:rest) id = 
  case lookup id scope of
    Nothing  -> lookupIdentifier rest id
    Just t  -> return t

addScope :: Environment -> Environment
addScope env = []:env -- Push new scope

