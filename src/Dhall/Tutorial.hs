{-# OPTIONS_GHC -fno-warn-unused-imports #-}

{-| Dhall is a programming language specialized for configuration files.  This
    module contains a tutorial explaning how to author configuration files using
    this language
-}
module Dhall.Tutorial (
    -- * Introduction
    -- $introduction

    -- * Types
    -- $types

    -- * Imports
    -- $imports

    -- * Lists
    -- $lists

    -- * Records
    -- $records

    -- * Functions
    -- $functions

    -- * Let expressions
    -- $let

    -- * Unions
    -- $unions

    -- * Generic functions
    -- $generics

    -- * Total
    -- $total

    -- * Built-in functions
    -- $builtins

    -- ** @Bool@
    -- $bool

    -- *** @(||)@
    -- $or

    -- *** @(&&)@
    -- $and

    -- *** @(==)@
    -- $equal

    -- *** @(/=)@
    -- $unequal

    -- *** @if@\/@then@\/@else@
    -- $ifthenelse

    -- ** @Natural@
    -- $natural

    -- *** @(+)@
    -- $plus

    -- *** @(*)@
    -- $times

    -- *** @Natural/even@
    -- $even

    -- *** @Natural/odd@
    -- $odd

    -- *** @Natural/isZero@
    -- $isZero

    -- *** @Natural/fold@
    -- $naturalFold

    -- *** @Natural/build@
    -- $naturalBuild
    ) where

import Data.Vector (Vector)
import Dhall (Interpret(..), Type, detailed, input)

-- $introduction
--
-- The simplest way to use Dhall is to ignore the programming language features
-- and use it as a strongly typed configuration format.  For example, suppose
-- that you create the following configuration file:
-- 
-- > $ cat > ./config <<EOF
-- > < Example =
-- >     { foo = 1
-- >     , bar = [3.0, 4.0, 5.0] : List Double
-- >     }
-- > >
-- > EOF
-- 
-- You can read the above configuration file into Haskell using the following
-- code:
-- 
-- > -- example.hs
-- > 
-- > {-# LANGUAGE DeriveGeneric     #-}
-- > {-# LANGUAGE OverloadedStrings #-}
-- > 
-- > import Dhall
-- > 
-- > data Example = Example { foo :: Integer , bar :: Vector Double }
-- >     deriving (Generic, Show)
-- > 
-- > instance Interpret Example
-- > 
-- > main :: IO ()
-- > main = do
-- >     x <- input auto "./config"
-- >     print (x :: Example)
-- 
-- If you compile and run the above program, the program prints the
-- corresponding Haskell record:
-- 
-- > $ ./example
-- > Example {foo = 1, bar = [3.0,4.0,5.0]}
--
-- You can also load some types directly into Haskell without having to define a
-- record, like this:
--
-- > >>> :set -XOverloadedStrings
-- > >>> input auto "True" :: IO Bool
-- > True
--
-- The `input` function can decode any value if we specify the value's expected
-- `Type`:
--
-- > input
-- >     :: Type a  -- Expected type
-- >     -> Text    -- Dhall program
-- >     -> IO a    -- Decoded expression
--
-- ... and we can either specify an explicit type like `bool`:
--
-- > bool :: Type Bool
-- > 
-- > input bool :: Text -> IO Bool
-- >
-- > input bool "True" :: IO Bool
-- >
-- > >>> input bool "True"
-- > True
--
-- ... or we can use `auto` to let the compiler infer what type to decode from
-- the expected return type:
--
-- > auto :: Interpret a => Type a
-- >
-- > input auto :: Interpret a => Text -> IO a
-- >
-- > >>> input auto "True" :: IO Bool
-- > True
--
-- You can see what types `auto` supports \"out-of-the-box\" by browsing the
-- instances for the `Interpret` class.  For example, the following instance
-- says that we can directly decode any Dhall expression that evaluates to a
-- @Bool@ into a Haskell `Bool`:
--
-- > instance Interpret Bool
--
-- ... which is why we could directly decode the string @\"True\"@ into a
-- Haskell `Bool`.
--
-- There is also another instance that says that if we can decode a value of
-- type @a@, then we can also decode a @List@ of values as a `Vector` of @a@s:
--
-- > instance Interpret a => Interpret (Vector a)
--
-- Therefore, since we can decode a @Bool@, we must also be able to decode a
-- @List@ of @Bool@s.  Let's verify that this works, too:
--
-- > >>> input auto "[True, False] : List Bool" :: IO (Vector Bool)
-- > [True,False]
--
-- We could have also used an explicit `Type` instead of `auto`:
--
-- > >>> input (vector bool) "[True, False] : List Bool"
-- > [True, False]

-- $types
--
-- Suppose that we try to decode a value of the wrong type, like this:
--
-- > >>> input auto "1" :: IO Bool
-- > *** Exception: 
-- > Error: Expression doesn't match annotation
-- > 
-- > 1 : Bool
-- > 
-- > (input):1:1
--
-- The interpreter complains because the string @\"1\"@ cannot be decoded into a
-- Haskell value of type `Bool`.
--
-- The code excerpt from the above error message has two components:
--
-- * the expression being type checked (i.e. @1@)
-- * the expression's expected type (i.e. @Bool@)
--
-- > Expression
-- > ⇩
-- > 1 : Bool
-- >     ⇧
-- >     Expected type
--
-- The @:@ symbol is how Dhall annotates values with their expected types.
-- Whenever you see:
--
-- > x : t
--
-- ... you should read that as \"we expect the expression @x@ to have type
-- @t@\". However, we might be wrong and if our expected type does not match the
-- expression's actual type then the type checker will complain.
--
-- If you are familiar with other functional programming languages, this
-- notation is equivalent to type annotations in Haskell using the @(::)@
-- symbol.
--
-- In this case, the expression @1@ does not have type @Bool@ so type checking
-- fails with an exception.

-- $imports
--
-- You might wonder why in some cases we can decode a configuration file:
--
-- > >>> writeFile "bool" "True"
-- > >>> input auto "./bool" :: IO Bool
-- > True
--
-- ... and in other cases we can decode a value directly:
--
-- > >>> input auto "True" :: IO Bool
-- > True
--
-- This is because importing a configuration from a file is a special case of a
-- more general language feature: Dhall expressions can reference other
-- expressions by their file path.
--
-- To illustrate this, let's create three files:
-- 
-- > $ echo 'True'  > bool1
-- > $ echo 'False' > bool2
-- > $ echo './bool1 && ./bool2' > both
--
-- ... and read in all three files in a single expression:
-- 
-- > >>> input auto "[ ./bool1 , ./bool2 , ./both ] : List Bool" :: IO (Vector Bool)
-- > [True,False,False]
--
-- Each file path is replaced with the Dhall expression contained within that
-- file.  If that file contains references to other files then those references
-- are transitively resolved.
--
-- In other words: configuration files can reference other configuration files,
-- either by their relative or absolute paths.  This means that we can split a
-- configuration file into multiple files, like this:
--
-- > $ cat > ./config <<EOF
-- > < Example =
-- >   { foo = 1
-- >   , bar = ./bar
-- >   }
-- > >
-- > EOF
--
-- > $ echo "[ 3.0, 4.0, 5.0 ] : List Double" > ./bar
--
-- > $ ./example
-- > Example {foo = 1, bar = [3.0,4.0,5.0]}
--
-- However, the Dhall language will forbid cycles in these file references.  For
-- example, if we create the following cycle:
--
-- > $ echo './file1' > file2
-- > $ echo './file2' > file1
--
-- ... then the interpreter will reject the import:
--
-- > >>> input auto "./file1" :: IO Integer
-- > *** Exception: 
-- > ↳ ./file1
-- >   ↳ ./file2
-- >
-- > Cyclic import: ./file1
--
-- You can also import expressions by URL.  For example, you can find a Dhall
-- expression hosted at this URL using @ipfs@:
--
-- <https://ipfs.io/ipfs/QmVf6hhTCXc9y2pRvhUmLk3AZYEgjeAz5PNwjt1GBYqsVB>
--
-- > $ curl https://ipfs.io/ipfs/QmVf6hhTCXc9y2pRvhUmLk3AZYEgjeAz5PNwjt1GBYqsVB
-- > True
--
-- ... and you can reference that expression either directly:
--
-- > >>> input auto "https://ipfs.io/ipfs/QmVf6hhTCXc9y2pRvhUmLk3AZYEgjeAz5PNwjt1GBYqsVB" :: IO Bool
-- > True
-- 
-- ... or inside of a larger expression:
--
-- > >>> input auto "False == https://ipfs.io/ipfs/QmVf6hhTCXc9y2pRvhUmLk3AZYEgjeAz5PNwjt1GBYqsVB" :: IO Bool
-- > False
--
-- You're not limited to hosting Dhall expressions on @ipfs@.  You can host a
-- Dhall expression anywhere that you can host raw plaintext on the web, such as
-- Github, a pastebin, or your own web server.
--
-- You can import types, too.  For example, we can change our @./bar@ file to:
--
-- > $ echo "[ 3.0, 4.0, 5.0 ] : List ./type" > ./bar
--
-- ... and then specify the @./type@ in a separate file:
--
-- > $ echo "Double" > ./type
--
-- > $ ./example
-- > Example {foo = 1, bar = [3.0,4.0,5.0]}

-- $lists
--
-- You can store 0 or more values of the same type in the list, like this:
--
-- > [1, 2, 3] : List Integer
--
-- Every list must be followed by the type of the list.  The type annotation is
-- not optional.  You will get an error if you omit the annotation:
--
-- > $ dhall
-- > [1, 2, 3]
-- > (stdin):2:1: error: unexpected
-- >     EOF, expected: ":"
-- > <EOF>
-- > ^
--
-- Also, the elements must all have the same type which must match the declare
-- type of the list.  You will get an error if you try to store any other type
-- of element:
--
-- > $ dhall
-- > [1, True, 3] : List Integer
-- > ^D
-- > Use "dhall --explain" for detailed errors
-- > 
-- > Error: List element has the wrong type
-- > 
-- > [1, True, 3] : List Integer
-- > 
-- > (stdin):1:1

-- $records
--
-- Record literals are delimited by curly braces and their fields are separated
-- by commas.  For example, this is a valid record literal:
--
-- > { foo = "ABC"
-- > , bar = 2
-- > , baz = 4.2
-- > }
--
-- A record type is like a record literal except instead of specifying each
-- field's value we specify each field's type instead.  For example, the
-- preceding record literal has the following record type:
--
-- > { foo : Text
-- > , bar : Integer
-- > , baz : Double
-- > }
--
-- You can access the field of a record using the following syntax:
--
-- > record.fieldName
--
-- ... which means to access the value of the field named @fieldName@ from the
-- @record@.  For example:
--
-- > $ dhall
-- > { foo = "ABC", bar = 2, baz = 4.2 }.baz
-- > <Ctrl-D>
-- > Double
-- > 
-- > 4.2

-- $functions
--
-- The Dhall programming language also supports user-defined anonymous
-- functions.  For example, we can save the following anonymous function to a
-- file:
--
-- > $ cat > makeBools
-- > \(n : Bool) ->
-- >         [ n && True, n && False, n || True, n || False ] : List Bool
-- > <Ctrl-D>
--
-- ... or we can use Dhall's support for Unicode characters to use @λ@ instead of
-- @\\@ and @→@ instead of @->@ (for people who are into that sort of thing):
--
-- > $ cat > makeBools
-- > λ(n : Bool) →
-- >         [ n && True, n && False, n || True, n || False ] : List Bool
-- > <Ctrl-D>
--
-- You can read either one as a function of one argument named @n@ that has type
-- @Bool@.  This function returns a @List@ of @Bool@s.  Each element of the
-- @List@ depends on the input argument.
--
-- The (ASCII) syntax for anonymous functions resembles the syntax for anonymous
-- functions in Haskell.  The only difference is that Dhall requires you to
-- annotate the type of the function's input.
--
-- We can test our @makeBools@ function directly from the command line. This
-- library comes with a command-line executable program named @dhall@ that you
-- can use to both type-check files and convert them to a normal form.  Our
-- compiler takes a program on standard input and then prints the program's type
-- to standard error followed by the program's normal form to standard output:
--
-- > $ dhall <<< "./makeBools"
-- > ∀(n : Bool) → List Bool
-- > 
-- > λ(n : Bool) → [n && True, n && False, n || True, n || False] : List Bool
--
-- The first line says that @makeBools@ is a function of one argument named @n@
-- that has type @Bool@ and the function returns a @List@ of @Bool@s.  The
-- second line is our program's normal form, which in this case happens to be
-- identical to our original program.
--
-- Functions are separated from their arguments by whitespace.  So if you see:
--
-- @f x@
--
-- ... you should read that as \"apply the function @f@ to the argument @x@\".
-- This means that we can \"apply\" our function to a @Bool@ argument like this:
--
-- > $ dhall <<< "./makeBools True"
-- > List Bool
-- > 
-- > [True, False, True, True] : List Bool
--
-- Remember that file paths are synonymous with their contents, so the above
-- code is equivalent to:
-- 
-- > $ dhall <<< "(λ(n : Bool) → [n && True, n && False, n || True, n || False] : List Bool) True"
-- > List Bool
-- > 
-- > [True, False, True, True] : List Bool
--
-- When you apply an anonymous function to an argument, you substitute the
-- \"bound variable" with the function's argument:
--
-- >    Bound variable
-- >    ⇩
-- > (λ(n : Bool) → ...) True
-- >                     ⇧
-- >                     Function argument
--
-- So in our above example, we would replace all occurrences of @n@ with @True@,
-- like this:
--
-- > -- If we replace all of these `n`s with `True` ...
-- > [n && True, n && False, n || True, n || False] : List Bool
-- >
-- > -- ... then we get this:
-- > [True && True, True && False, True || True, True || False] : List Bool
-- >
-- > -- ... which reduces to the following normal form:
-- > [True, False, True, True] : List Bool
--
-- Now that we've verified that our function type checks and works, we can use
-- the same function within Haskell:
--
-- > >>> input auto "./makeBools True" :: IO (Vector Bool)
-- > [True,False,True,True]

-- $let
--
-- Dhall also supports @let@ expressions, which you can use to define
-- intermediate values in the course of a computation.
--
-- Here is an example @let@ expression:
--
-- > $ dhall
-- > let x = "ha" in x ++ x
-- > <Ctrl-D>
-- > Text
-- >
-- > "haha"
--
-- You can also annotate the types of values defined within a @let@ expression,
-- like this:
--
-- > $ dhall
-- > let x : Text = "ha" in x ++ x
-- > <Ctrl-D>
-- > Text
-- >
-- > "haha"
--
-- Every @let@ expression of the form:
--
-- > let x : t = y in e
--
-- ... is exactly equivalent to:
--
-- > (λ(x : t) → e) y
--
-- So for example, this @let@ expression:
--
-- > let x : Text = "ha" in x ++ x
--
-- ... is equivalent to:
--
-- > (λ(x : Text) → x ++ x) "ha"
--
-- ... which in turn simplifies to:
--
-- > "ha" ++ "ha"
--
-- You need to nest @let@ expressions if you want to define more than one value
-- in this way:
--
-- > $ dhall
-- >     let x = "Hello, "
-- > in  let y = "world!"
-- > in  x ++ y
-- > <Ctrl-D>
-- > Text
-- > 
-- > "Hello, world!"
--
-- Dhall is completely whitespace-insensitive, so feel free to format things
-- over multiple lines or indent in any way that you please.
--
-- If you want to define a named function, just give a name to an anonymous
-- function:
--
-- > $ dhall
-- > let twice = λ(x : Text) → x ++ x in twice "ha"
-- > <Ctrl-D>
-- > Text
-- > 
-- > "haha"
--
-- Unlike Haskell, Dhall does not support function arguments on the left-hand
-- side of the equals sign, so this will not work:
--
-- > $ dhall
-- > let twice (x : Text) = x ++ x in twice "ha"
-- > <Ctrl-D>
-- > (stdin):1:11: error: expected: ":",
-- >     "="
-- > let twice (x : Text) = x ++ x in twice "ha" 
-- >           ^
--
-- The error message says that Dhall expected either a @(:)@ (i.e. the beginning
-- of a type annotation) or a @(=)@ (the beginning of the assignment) and not a
-- function argument.

-- $unions
--
-- A union is a value that can be one of many alternative types of values.  For
-- example, the following union type:
--
-- > < Left : Natural | Right : Bool >
--
-- ... represents a value that can be either an @Integer@ or a @Text@ value.
-- If you are familiar with Haskell these are exactly analogous to Haskell's
-- \"sum types\".  You can think of them as anonymous sum types.
--
-- Each alternative is associated with a tag that distinguishes that alternative
-- from others.  In the above example, the @Left@ tag is used for the @Natural@
-- alternative and the @Right@ tag is used for the @Bool@ alternative.
--
-- A union literal specifies the value of one alternative and the types of the
-- remaining alternatives.  For example, both of the following union literals
-- have the above union type:
--
-- > < Left  = +0   | Right : Bool    >
--
-- > < Right = True | Left  : Natural >
--
-- You can consume a union using the built-in @merge@ function.  For example,
-- suppose we want to convert our union to a @Bool@ but we want to behave
-- differently depending on whether or not the union is an @Integer@ wrapped in
-- the @Left@ tag or a @Bool@ wrapped in the @Right@ tag.  We would write:
--
-- > $ cat > process <<EOF
-- >     λ(union : < Left : Natural | Right : Bool >)
-- > →   let handlers =
-- >             { Left  = Natural/even
-- >             , Right = λ(b : Bool) → b
-- >             }
-- > in  merge handlers union : Bool
-- > EOF
--
-- Now our @./process@ function can handle both alternatives:
--
-- > $ dhall
-- > ./process < Left = +3 | Right : Bool >
-- > Bool
-- > 
-- > False
--
-- > ./process < Right = True | Left : Natural >
-- > Bool
-- > 
-- > True
--
-- Every @merge@ function is of the form:
--
-- > merge handlers union : type
--
-- ... where: 
--
-- * @union@ is the union you want to consume
-- * @handlers@ is a record with one function per alternative of the union.
-- * @type@ is the declared result type of the @merge@
--
-- The @merge@ function selects which function to apply depending on which
-- alternative the union selects:
--
-- > merge { Foo = f, ... } < Foo = x | ... > : t = f x : t
--
-- So, for example:
--
-- > merge { Left = Natural/even, Right = λ(b : Bool) → b } < Left = +3 | Right : Bool > : Bool
-- >     = Natural/even +3 : Bool
-- >     = False
--
-- ... and similarly:
--
-- > merge { Left = Natural/even, Right = λ(b : Bool) → b } < Right = True | Left : Natural > : Bool
-- >     = (λ(b : Bool) → b) True : Bool
-- >     = True
--
-- Notice that each handler has to return the same type of result (@Bool@ in
-- this case) which must also match the declared result type of the @merge@.

-- $generics
--
-- The Dhall language supports defining generic functions (a.k.a.
-- \"polymorphic\" functions) that work on more than one type of value.
-- However, Dhall differs from Haskell by not inferring the types of these
-- generic functions.  Instead, you must be explicit about what type of value
-- the function is specialized to.
--
-- Take, for example, Haskell's identity function named @id@:
--
-- > id :: a -> a
-- > id = \x -> x
--
-- The identity function is generic, meaning that `id` works on values of
-- different types:
--
-- > >>> id 4
-- > 4
-- > >>> id True
-- > True
--
-- The equivalent function in Dhall is:
--
-- > λ(a : Type) → λ(x : a) → x
--
-- Notice how this function takes two arguments instead of one.  The first
-- argument is the type of the second argument.
--
-- Let's illustrate how this works by actually using the above function:
--
-- > $ echo "λ(a : Type) → λ(x : a) → x" > id
--
-- If we supply the function alone to the compiler we get the inferred type as
-- the first line:
-- 
-- > $ dhall <<< "./id"
-- > ∀(a : Type) → ∀(x : a) → a
-- > 
-- > λ(a : Type) → λ(x : a) → x
--
-- You can read the type @(∀(a : Type) → ∀(x : a) → a)@ as saying: \"This is the
-- type of a function whose first argument is named @a@ and is a @Type@.  The
-- second argument is named @x@ and has type @a@ (i.e. the value of the first
-- argument).  The result also has type @a@.\"
--
-- This means that the type of the second argument changes depending on what
-- type we provide for the first argument:
--
-- > $ dhall <<< "./id Integer"
-- > ∀(x : Integer) → Integer
-- > 
-- > λ(x : Integer) → x
--
-- > $ dhall <<< "./id Bool"
-- > ∀(x : Bool) → Bool
-- > 
-- > λ(x : Bool) → x
--
-- When we apply @./id@ to @Integer@, we create a function that expects an
-- @Integer@ argument.  Similarly, when we instead apply @./id@ to @Bool@, we
-- create a function that expects a @Bool@ argument.
--
-- We can then supply the final argument to each of those functions to show
-- that they work:
--
-- > $ dhall <<< "./id Integer 4"
-- > Integer
-- > 
-- > 4
--
-- > $ dhall <<< "./id Bool True"
-- > Bool
-- > 
-- > True
--
-- Built-in functions can also be generic, too.  For example, we can ask the
-- compiler for the type of @List/reverse@, the function that reverses a list:
--
-- > $ dhall <<< "List/reverse"
-- > ∀(a : Type) → List a → List a
-- > 
-- > List/reverse
--
-- The first argument to @List/reverse@ is the type of the list to reverse:
--
-- > $ dhall <<< "List/reverse Bool"
-- > List Bool → List Bool
-- > 
-- > List/reverse Bool
--
-- ... and the second argument is the list to reverse:
--
-- > $ dhall <<< "List/reverse Bool ([True, False] : List Bool)"
-- > List Bool
-- > 
-- > [False, True] : List Bool
--
-- Note that the second argument has no name.  This type:
--
-- > ∀(a : Type) → List a → List a
--
-- ... is equivalent to this type:
--
-- > ∀(a : Type) → ∀(_ : List a) → List a
--
-- In other words, if you don't see the @∀@ symbol surrounding a function
-- argument type then that means that the name of the argument is @"_"@.  This
-- is true even for user-defined functions:
--
-- > $ dhall <<< "λ(_ : Text) → 1"
-- > Text → Integer
-- > 
-- > λ(_ : Text) → 1
--
-- The type @(Text → Integer)@ is the same as @(∀(_ : Text) → Integer)@

-- $total
--
-- Dhall is a total programming language, which means that Dhall is not
-- Turing-complete and evaluation of every Dhall program is guaranteed to
-- eventually halt.  There is no upper bound on how long the program might take
-- to evaluate, but the program is guaranteed to terminate in a finite amount of
-- time and not hang forever.
--
-- This guarantees that all Dhall programs can be safely reduced to a normal
-- form where all functions have been evaluated.  In fact, Dhall expressions can
-- be evaluated even if all function arguments haven't been fully applied.  For
-- example, the following program is an anonymous function:
--
-- > $ dhall
-- > \(n : Bool) -> +10 * +10
-- > <Ctrl-D>
-- > ∀(n : Bool) → Natural
-- > 
-- > λ(n : Bool) → +100
--
-- ... and even though the function is still missing the first argument named
-- @n@ the compiler is smart enough to evaluate the body of the anonymous
-- function ahead of time before the function has even been invoked.
--
-- We can use the @map@ function from the Prelude to illustrate an even more
-- complex example:
--
-- > $ dhall
-- >     let map = https://ipfs.io/ipfs/QmNnkjXfe3oP62w7Yx75DNCSGkWWK2iinHboF38fkYMZUP/Prelude/List/map
-- > in  λ(f : Integer → Integer) → map Integer Integer f ([1, 2, 3] : List Integer)
-- > <Ctrl-D>
-- > ∀(f : Integer → Integer) → List Integer
-- > 
-- > λ(f : Integer → Integer) → [f 1, f 2, f 3] : List Integer
--
-- Dhall knows to apply our function to each element of the list even before
-- we specify which function to apply.
--
-- The language will also never crash or throw any exceptions.  Every
-- computation will succeed and produce something, even if the result might be
-- an @Optional@ value.

-- $builtins
--
-- Dhall is a restricted programming language that only supports simple built-in
-- functions and operators.  If you wish to do anything fancier you will need to
-- load your data into Haskell for further processing
--
-- The language provides support for the following primitive types:
--
-- * @Bool@ values
-- * @Natural@ values
-- * @Integer@ values
-- * @Double@ values
-- * @Text@ values
--
-- ... as well as support for the following derived types:
--
-- * @List@s of values
-- * @Optional@ values
-- * Anonymous records
-- * Anonymous unions
--
-- Dhall differs in a few important ways from other programming languages, so
-- you should keep the following caveats in mind:
--
-- First, Dhall only supports addition and multiplication on @Natural@ numbers
-- (i.e. non-negative numbers), which are not the same type of number as
-- @Integer@s (which can be negative).  A @Natural@ number is a number prefixed
-- with the @+@ symbol.  If you try to add or multiply two @Integer@s (without
-- the @+@ prefix) you will get a type error:
--
-- > $ dhall
-- > 2 + 2
-- > <Ctrl-D>
-- > Use "dhall --explain" for detailed errors
-- > 
-- > Error: ❰+❱ only works on ❰Natural❱s
-- > 
-- > 2 + 2
-- > 
-- > (stdin):1:1
--
-- In fact, there are no built-in functions for @Integer@s (or @Double@s).  As
-- far as the language is concerned they are opaque values that can only be
-- shuffled around but not used in any meaningful way until they have been
-- loaded into Haskell.
--
-- Second, the equality @(==)@ and inequality @(/=)@ operators only work on
-- @Bool@s.  You cannot test any other types of values for equality.
--
-- Each of the following sections provides an overview of builtin functions and
-- operators for each type.  For each function you get:
--
-- * An example use of that function
--
-- * A \"type judgement\" explaining when that function or operator is well
--   typed
--
-- For example, for the following judgement:
--
-- > Γ ⊢ x : Bool   Γ ⊢ y : Bool
-- > ───────────────────────────
-- > Γ ⊢ x && y : Bool
--
-- ... you can read that as saying: "if @x@ has type @Bool@ and @y@ has type
-- @Bool@, then @x && y@ has type @Bool@"
--
-- Similarly, for the following judgement:
--
-- > ─────────────────────────────────
-- > Γ ⊢ Natural/even : Natural → Bool
--
-- ... you can read that as saying: "@Natural/even@ always has type
-- @Natural → Bool@"
--
-- * Rules for how that function or operator behaves
--
-- These rules are just equalities that come in handy when reasoning about code.
-- For example, the section on @(&&)@ has the following rules:
--
-- > (x && y) && z = x && (y && z)
-- >
-- > x && True = x
-- >
-- > True && x = x
--
-- These rules are also a contract for how the compiler should behave.  If you
-- ever observe code that does not obey these rules you should file a bug
-- report.

-- $bool
--
-- There are two values that have type @Bool@ named @True@ and @False@:
--
-- > ───────────────
-- > Γ ⊢ True : Bool
--
-- > ────────────────
-- > Γ ⊢ False : Bool
--
-- The built-in operations for values of type @Bool@ are:
--

-- $or
--
-- Example:
--
-- > $ dhall
-- > True || False
-- > <Ctrl-D>
-- > Bool
-- > 
-- > True
--
-- Type:
--
-- > Γ ⊢ x : Bool   Γ ⊢ y : Bool
-- > ───────────────────────────
-- > Γ ⊢ x || y : Bool
--
-- Laws:
--
-- > (x || y) || z = x || (y || z)
-- > 
-- > x || False = x
-- > 
-- > False || x = x
-- >
-- > x || (y && z) = (x || y) && (x || z)
-- > 
-- > x || True = True
-- > 
-- > True || x = True

-- $and
--
-- Example:
--
-- > $ dhall
-- > True && False
-- > <Ctrl-D>
-- > Bool
-- > 
-- > False
--
-- Type:
--
-- > Γ ⊢ x : Bool   Γ ⊢ y : Bool
-- > ───────────────────────────
-- > Γ ⊢ x && y : Bool
--
-- Laws:
--
-- > (x && y) && z = x && (y && z)
-- > 
-- > x && True = x
-- > 
-- > True && x = x
-- >
-- > x && (y || z) = (x && y) || (x && z)
-- > 
-- > x && False = False
-- > 
-- > False && x = False

-- $equal
--
-- Example:
--
-- > $ dhall
-- > True == False
-- > <Ctrl-D>
-- > Bool
-- > 
-- > False
--
-- Type:
--
-- > Γ ⊢ x : Bool   Γ ⊢ y : Bool
-- > ───────────────────────────
-- > Γ ⊢ x == y : Bool
--
-- Laws:
--
-- > (x == y) == z = x == (y == z)
-- > 
-- > x == True = x
-- > 
-- > True == x = x
-- >
-- > x == x = True

-- $unequal
--
-- Example:
--
-- > $ dhall
-- > True != False
-- > <Ctrl-D>
-- > Bool
-- > 
-- > True
--
-- Type:
--
-- > Γ ⊢ x : Bool   Γ ⊢ y : Bool
-- > ───────────────────────────
-- > Γ ⊢ x != y : Bool
--
-- Laws:
--
-- > (x != y) != z = x != (y != z)
-- > 
-- > x != False = x
-- > 
-- > False != x = x
-- >
-- > x != x = False

-- $ifthenelse
--
-- Example:
--
-- > $ dhall
-- > if True then 3 else 5
-- > <Ctrl-D>
-- > Integer
-- > 
-- > 3
--
-- Type:
--
-- >                Γ ⊢ t : Type
-- >                ─────────────────────
-- > Γ ⊢ b : Bool   Γ ⊢ l : t   Γ ⊢ r : t
-- > ────────────────────────────────────
-- > Γ ⊢ if b then l else r
--
-- Laws:
--
-- > if b then True else False = b
-- > 
-- > if True  then l else r = l
-- > 
-- > if False then l else r = r

-- $natural
--
-- Natural literals are numbers prefixed by a @+@ sign, like this:
--
-- > +4 : Natural
--
-- If you omit the @+@ sign then you get an @Integer@ literal, which is a
-- different type of value

-- $plus
--
-- Example:
--
-- > $ dhall
-- > +2 + +3
-- > <Ctrl-D>
-- > Natural
-- > 
-- > +5
--
-- Type:
--
-- > Γ ⊢ x : Natural   Γ ⊢ y : Natural
-- > ────────────────────────────────
-- > Γ ⊢ x + y : Natural
--
-- Rules:
--
-- > (x + y) + z = x + (y + z)
-- >
-- > x + +0 = x
-- >
-- > +0 + x = x

-- $times
--
-- Example:
--
-- > $ dhall
-- > +2 * +3
-- > <Ctrl-D>
-- > Natural
-- > 
-- > +6
--
-- Type:
--
-- > Γ ⊢ x : Natural   Γ ⊢ y : Natural
-- > ────────────────────────────────
-- > Γ ⊢ x * y : Natural
--
-- Rules:
--
-- > (x * y) * z = x * (y * z)
-- >
-- > x * +1 = x
-- >
-- > +1 * x = x
-- >
-- > (x + y) * z = (x * z) + (y * z)
-- >
-- > x * (y + z) = (x * y) + (x * z)
-- >
-- > x * +0 = +0
-- >
-- > +0 * x = +0

-- $even
--
-- Example:
--
-- > $ dhall
-- > Natural/even +6
-- > <Ctrl-D>
-- > Bool
-- > 
-- > True
--
-- Type:
--
-- > ─────────────────────────────────
-- > Γ ⊢ Natural/even : Natural → Bool
--
-- Rules:
--
-- > Natural/even (x + y) = Natural/even x == Natural/even y
-- >
-- > Natural/even +0 = True
-- >
-- > Natural/even (x * y) = Natural/even x || Natural/even y
-- >
-- > Natural/even +1 = False

-- $odd
--
-- Example:
--
-- > $ dhall
-- > Natural/odd +6
-- > <Ctrl-D>
-- > Bool
-- > 
-- > False
--
-- Type:
--
-- > ────────────────────────────────
-- > Γ ⊢ Natural/odd : Natural → Bool
--
-- Rules:
--
-- > Natural/odd (x + y) = Natural/odd x /= Natural/odd y
-- >
-- > Natural/odd +0 = False
-- >
-- > Natural/odd (x * y) = Natural/odd x && Natural/odd y
-- >
-- > Natural/odd +1 = True

-- $isZero
--
-- Example:
--
-- > $ dhall
-- > Natural/isZero +6
-- > <Ctrl-D>
-- > Bool
-- > 
-- > False
--
-- Type:
--
-- > ───────────────────────────────────
-- > Γ ⊢ Natural/isZero : Natural → Bool
--
-- Rules:
--
-- > Natural/isZero (x + y) = Natural/isZero x && Natural/isZero y
-- >
-- > Natural/isZero +0 = True
-- >
-- > Natural/isZero (x * y) = Natural/isZero x || Natural/isZero y
-- >
-- > Natural/isZero +1 = False

-- $naturalFold
--
-- Example:
--
-- > $ dhall
-- > Natural/fold +40 Text (λ(t : Text) → t ++ "!") "You're welcome"
-- > <Ctrl-D>
-- > Text
-- > 
-- > "You're welcome!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
--
-- Type:
--
-- > ──────────────────────────────────────────────────────────
-- > Γ ⊢ Natural/fold : Natural → ∀(a : Type) → (a → a) → a → a
--
-- Rules:
-- 
-- > Natural/fold (x + y) n s z = Natural/fold x n s (Natural/fold y n s z)
-- > 
-- > Natural/fold +0 n s z = z
-- > 
-- > Natural/fold (x * y) n s = Natural/fold x n (Natural/fold y n s)
-- > 
-- > Natural/fold 1 n s = s

-- $naturalBuild
--
-- Example:
--
-- > $ dhall
-- > Natural/build (λ(a : Type) → λ(succ : a → a) → λ(zero : a) → succ (succ zero))
-- > <Ctrl-D>
-- > Natural
-- > 
-- > +2
--
-- Type:
--
-- > ─────────────────────────────────────────────────────────────
-- > Γ ⊢ Natural/build : (∀(a : Type) → (a → a) → a → a) → Natural
--
-- Rules:
--
-- > Natural/fold (Natural/build x) = x
-- >
-- > Natural/build (Natural/fold x) = x
