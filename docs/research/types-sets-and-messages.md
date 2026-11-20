# Types as sets, types as propositions, objects as message receivers

Research notes for a coding style built on set theory and type theory, and for whether it carries over to object-oriented message passing. Sections 1 to 4 are sourced claims; every claim names its source, listed under [References](#references). Section 5 is synthesis.

Verification marks:

- **[read]** I read the claim in the primary source (its page, PDF, or official docs).
- **[biblio]** I confirmed the paper and its bibliographic details, but could not read the passage. The claim is the standard reading of the work and should be checked against the text before it is quoted.

## 1. Types as sets

### Origins

- Type theory began as a fix for paradoxes in set theory. Russell introduced a doctrine of types (Appendix B of *The Principles of Mathematics*, 1903) and developed it in "Mathematical Logic as Based on the Theory of Types" (1908) [Russell 1908]. **[biblio]** The 1903 placement comes from the Stanford Encyclopedia of Philosophy, which is a secondary source; Russell 1908 is the primary.
- Church's simple theory of types (1940) reformulated type theory using the λ-calculus, with functions as primitive objects and each term carrying a type [Church 1940]. **[biblio]**

### Types as sets of values in programming

- Cardelli and Wegner (1985) have a section titled "Types are Sets of Values". They take the universe of all values, treat a type as a subset of it, and read subtyping as set inclusion. The same paper puts abstract data types, parametric polymorphism, and inheritance in one framework [Cardelli & Wegner 1985]. **[biblio]** I confirmed the section heading but could not extract the body text.

### Where the set view breaks

- Reynolds (1984) showed that the polymorphic λ-calculus (System F) has no model in which types denote sets and `A → B` denotes the set of *all* functions from A to B [Reynolds 1984]. **[biblio]** Pitts later showed that the result does not depend on classical logic: it also holds in constructive set theory. The practical lesson: "a type is a set of values" is a sound guide for first-order data such as records, unions, and literals. Applied naively to impredicative polymorphism (types quantified over all types, including themselves), it fails.

### Set-theoretic types in practice

- **Semantic subtyping (CDuce).** Frisch, Castagna and Benzaken define subtyping from a set-theoretic model: `s ≤ t` holds when the set of values of `s` is a subset of the set of values of `t`. The type algebra has union, intersection and negation, and covers function types as well [Frisch, Castagna & Benzaken 2008]. **[biblio]** The title, "dealing set-theoretically with function, union, intersection, and negation types", states the programme.
- **Elixir.** Elixir's official docs say its type system is "composed using basic set operations: unions, intersections, and negation". They also define `none()` as the empty set, `term()` as the set of all values, and `dynamic()` as a range of types for gradual typing [Elixir docs]. **[read]** The design is described in Castagna, Duboc & Valim (2023/24) [CDV 2024] **[read: abstract]**. The guard analysis and the safe-erasure gradual typing are formalised in Castagna & Duboc (2024) [CD 2024] **[read: abstract]**. Valim is not an author of that second paper.
- **TypeScript.** The Handbook says TypeScript uses `never` "to represent a state which shouldn't exist". Assigning to `never` in a `default` branch gives exhaustiveness checking. A *type predicate* (`pet is Fish`) narrows a union inside a branch [TS Narrowing]. **[read]** Another Handbook page notes that TypeScript unions are untagged, unlike Haskell's `data`, and that it also has intersections (`A & B`) [TS for FP]. **[read]** The Handbook does not use the word "set" for this.

## 2. Types as propositions

- **Curry–Howard.** Howard's manuscript "The formulae-as-types notion of construction" (1969) shows that proofs in intuitionistic natural deduction correspond to typed λ-terms, and proof normalisation corresponds to evaluation. It circulated in 1969 and was published in 1980 in the Curry Festschrift [Howard 1980]. **[biblio]** Wadler confirms the 1969/1980 dates and traces the correspondence back to Curry's 1934 observation [Wadler 2015]. **[read: via CACM record and Wadler's own pages]**
- **Martin-Löf type theory.** Martin-Löf extends the correspondence to dependent types: Σ (pair) types, Π (function) types, and identity types. Propositions *are* types, and a proof is a term of the type [Martin-Löf 1984]. **[biblio]** Wadler names Martin-Löf's type theory as a key 1970s contribution [Wadler 2015].
- **Wadler, "Propositions as Types" (CACM 2015).** This is the accessible primary account. Propositions correspond to types, proofs to programs, and proof simplification to evaluation. Conjunction is the product type, disjunction the sum type, implication the function type [Wadler 2015]. **[read: bibliographic + summary]**

## 3. Design idioms that follow

- **"Make illegal states unrepresentable."** Yaron Minsky coined the phrase as a section heading in "Effective ML Revisited" (Jane Street blog, 9 March 2011). He uses it to restructure a connection-state record so that impossible field combinations cannot be built [Minsky 2011]. **[read]** Minsky has said elsewhere that the idea is older than the phrase; I did not find that statement at a primary source.
- **"Parse, don't validate."** Alexis King (2019) calls a parser "a function that consumes less-structured input and produces more-structured output". Validation checks input and throws away what it learned. Parsing keeps that knowledge in the return type, so later code cannot meet the unchecked case [King 2019]. **[read]**
- **Algebraic data types as sums and products.** Under propositions-as-types, a product is a conjunction and a sum is a disjunction [Wadler 2015]. Under types-as-sets, a product is a Cartesian product and a tagged sum is a disjoint union [Cardelli & Wegner 1985]. The cardinality arithmetic follows from this: |A × B| = |A|·|B|, |A + B| = |A| + |B|, |A → B| = |B|^|A|. **Unverified at a primary source:** I found no single originating paper for the "count the inhabitants" framing as a design tool. It is folklore that follows from the set semantics above, so cite the set semantics, not a coiner.
- **Refinement types.** Freeman and Pfenning (PLDI 1991) introduced refinement types: subsets of an existing ML datatype, checked without changing the language of programs [Freeman & Pfenning 1991]. **[biblio + abstract]** LiquidHaskell (Vazou et al., ICFP 2014) refines types with logical predicates checked by an SMT solver, for example `{v:Int | v > 0}`. Here the predicate *is* the subset [Vazou et al. 2014]. **[biblio + abstract]**

## 4. OOP as message passing

- **Alan Kay.** In "The Early History of Smalltalk" (HOPL-II, 1993), Kay lists Smalltalk-72's principles. The first is "Everything is an object"; the second is "Objects communicate by sending and receiving messages (in terms of objects)". He also calls Smalltalk "a recursion on the notion of computer itself" [Kay 1993]. **[read]** In a squeak-dev post of 10 October 1998, Kay wrote that "The big idea is 'messaging'". In the same post he said he regretted coining the term "objects" because it drew attention to the lesser idea [Kay 1998]. **[read]**
- **Actors.** Hewitt, Bishop and Steiger (IJCAI 1973) made the actor the single primitive of computation, with message sending as its only means of interaction. The formalism needs no goto, interrupt, or semaphore primitives [Hewitt et al. 1973]. **[biblio + abstract]**
- **Objects versus abstract data types.** Cook (OOPSLA Onward! 2009) argues that objects and ADTs are distinct forms of data abstraction. In his summary, "An object is a value exporting a procedural interface to data or behavior". In his integer-set example, a set "is 'represented' by the observations that can be performed upon it". He also names the *autognostic principle*: an object can reach other objects only through their public interfaces. ADTs hide a representation *type*; objects hide behaviour behind procedures [Cook 2009]. **[read]** This is the type-theoretic statement of Kay's point: an object's type is the set of messages it answers.
- **Coalgebra: the dual of algebraic data.** Jacobs and Rutten's tutorial presents algebras as the semantics of data built by constructors, and *coalgebras* as the semantics of state-based systems observed by destructors: automata, transition systems, and objects. Bisimulation (equal behaviour under all observations) replaces structural equality, and coinduction replaces induction [Jacobs & Rutten 1997]. **[biblio]** I could not extract the text, so I have not quoted it. In this reading, an algebraic data type is defined by how you *build* it, and an object or state machine is defined by how you *observe* it, that is, the messages it answers.
- **Session types (behavioural types).** Honda (CONCUR 1993) types a communication channel by the *sequence* of messages that may pass over it [Honda 1993]. Honda, Vasconcelos and Kubo (ESOP 1998) give language primitives for structured, typed conversations [HVK 1998]. Gay and Hole (2005) add subtyping: a session type may be replaced by one that offers more choices or demands fewer [Gay & Hole 2005]. **[biblio]** A session type is a state machine over messages, checked statically.
- **Typestate.** Strom and Yemini (IEEE TSE 1986) call typestate "a refinement of the concept of type". The operations allowed on a value depend on its current state, for example whether it is initialised, and the compiler tracks that state [Strom & Yemini 1986]. **[biblio + abstract]**
- **Behavioural subtyping.** Liskov and Wing (TOPLAS 1994) require that properties provable from a supertype's specification still hold for objects of the subtype, including history constraints on how state may change [Liskov & Wing 1994]. **[biblio + abstract]** In set terms, a subtype must be substitutable: it accepts at least the messages the supertype accepts, and its observable behaviours stay within those the supertype's specification allows.
- **Erlang processes.** Armstrong's thesis (KTH, 2003) builds fault-tolerant systems from isolated processes that share nothing and interact only by asynchronous messages. Each process selects messages with `receive` and pattern matching [Armstrong 2003]. **[biblio]** I confirmed the thesis but did not re-read the passages. In Elixir, the `receive` clauses and the set-theoretic types above can, in principle, describe exactly which messages a process handles.

## 5. Synthesis (not sourced claims)

This section is my synthesis. It is not attributed to any source above.

### Candidate rules

1. **A type names a set of values.** Pick the smallest set that is still honest. A type that admits a value the domain forbids is a bug waiting for an input. (Minsky; Cardelli & Wegner.)
2. **A predicate narrows a set.** Every business-rule predicate, such as `isOverdue` or `isEligible`, defines a subset. Where the language allows, give the subset a name and a type: a refinement, a branded or newtype wrapper, or a narrowed union. That way code downstream of the check cannot forget it. (Freeman & Pfenning; LiquidHaskell; TS type predicates.)
3. **Parse at the boundary, once.** The shell turns raw input into the narrowest type. The core never sees the wider set. (King.) This is the existing "validate at boundaries" rule, with the result carried in the type.
4. **Sums for "or", products for "and", nothing for "except".** Model alternatives as tagged unions and combinations as records. Use exhaustiveness (`never` in TypeScript, pattern-match warnings in ML, Haskell and Rust) so that adding a case is a compile error at every decision point. Use negation and difference where the type system has them (Elixir `not`, CDuce).
5. **A message's type is the set of messages an object accepts.** Describe an object or process by its accepted messages, written as a union of message shapes, not by its fields. Callers depend on that set alone (Kay; Cook's autognosis). A subtype may accept more messages, never fewer, and must keep the supertype's promised behaviour (Liskov & Wing).
6. **A state machine's legal moves are a set.** The transition table is a finite set of `(state, event) → state` triples, and anything outside it is an error. Where the language can express it, make the legal events depend on the state (typestate, session types). Then an illegal call becomes a type error, not a runtime error.
7. **Observe, don't inspect.** Two objects are equal when no message tells them apart (bisimulation). Tests of an object or process should send messages and check replies. They should not reach into its state (Jacobs & Rutten; Cook).
8. **Know the limit.** The set reading is reliable for first-order data. For higher-rank polymorphism, rely on parametricity instead (Reynolds).

### How this relates to functional-first

- "Rules that select things are sets" already treats predicates as sets. Rules 1 to 2 push that into the type, so that the result of a selection carries its predicate.
- "Lifecycles are state machines" already keeps one transition table as data, read by a pure `step`. Rule 6 restates the table as a set of legal pairs, and suggests typestate or session types when the language supports them. The data table stays the source of truth.
- "Pure core, thin shell" matches rule 3: the shell parses, the core works only on narrowed types.
- "Test laws" matches rule 7 and the Liskov–Wing view. A property test over random event sequences checks bisimulation-style behaviour, and a check of the transition table against the requirement checks set equality.
- New relative to the current skill: rule 5, the message-set view of objects and processes. It is the bridge for OOP and Elixir/Erlang code, where the unit of design is a receiver, not a function.

## References

- Armstrong, J. (2003). *Making reliable distributed systems in the presence of software errors.* PhD thesis, KTH / SICS Dissertation Series 34. https://erlang.org/download/armstrong_thesis_2003.pdf
- Cardelli, L., & Wegner, P. (1985). On understanding types, data abstraction, and polymorphism. *ACM Computing Surveys* 17(4), 471–522. https://doi.org/10.1145/6041.6042 (PDF: http://lucacardelli.name/Papers/OnUnderstanding.A4.pdf)
- Castagna, G., & Duboc, G. (2024). Guard analysis and safe erasure gradual typing: a type system for Elixir. arXiv:2408.14345. https://arxiv.org/abs/2408.14345
- Castagna, G., Duboc, G., & Valim, J. (2024). The design principles of the Elixir type system. *The Art, Science, and Engineering of Programming* 8(2), Article 4. arXiv:2306.06391. https://doi.org/10.22152/programming-journal.org/2024/8/4
- Church, A. (1940). A formulation of the simple theory of types. *Journal of Symbolic Logic* 5(2), 56–68. https://doi.org/10.2307/2266170
- Cook, W. R. (2009). On understanding data abstraction, revisited. *OOPSLA 2009 (Onward! essays)*, 557–572. https://doi.org/10.1145/1640089.1640133 (PDF: https://www.cs.utexas.edu/~wcook/Drafts/2009/essay.pdf)
- Elixir docs. Gradual set-theoretic types. https://hexdocs.pm/elixir/gradual-set-theoretic-types.html
- Freeman, T., & Pfenning, F. (1991). Refinement types for ML. *PLDI '91*, 268–277. https://doi.org/10.1145/113445.113468 (PDF: https://www.cs.cmu.edu/~fp/papers/pldi91.pdf)
- Frisch, A., Castagna, G., & Benzaken, V. (2008). Semantic subtyping: dealing set-theoretically with function, union, intersection, and negation types. *Journal of the ACM* 55(4). https://doi.org/10.1145/1391289.1391293 (PDF: https://www.irif.fr/~gc/papers/semantic_subtyping.pdf)
- Gay, S. J., & Hole, M. (2005). Subtyping for session types in the pi calculus. *Acta Informatica* 42(2–3), 191–225. https://doi.org/10.1007/s00236-005-0177-z
- Hewitt, C., Bishop, P., & Steiger, R. (1973). A universal modular ACTOR formalism for artificial intelligence. *IJCAI-73*, 235–244. https://www.ijcai.org/Proceedings/73/Papers/027B.pdf (index: https://ijcai.org/proceedings/1973/31)
- Honda, K. (1993). Types for dyadic interaction. *CONCUR '93*, LNCS 715, 509–523. https://doi.org/10.1007/3-540-57208-2_35
- Honda, K., Vasconcelos, V. T., & Kubo, M. (1998). Language primitives and type discipline for structured communication-based programming. *ESOP '98*, LNCS 1381, 122–138. https://doi.org/10.1007/BFb0053567
- Howard, W. A. (1980). The formulae-as-types notion of construction. In Seldin & Hindley (eds.), *To H. B. Curry: Essays on Combinatory Logic, Lambda Calculus and Formalism*, Academic Press, 479–490. Manuscript circulated 1969.
- Jacobs, B., & Rutten, J. (1997). A tutorial on (co)algebras and (co)induction. *EATCS Bulletin* 62, 222–259. https://www.cs.ru.nl/B.Jacobs/PAPERS/JR.pdf
- Kay, A. C. (1993). The early history of Smalltalk. *HOPL-II*, *SIGPLAN Notices* 28(3), 69–95. https://doi.org/10.1145/154766.155364 (author-corrected text: https://worrydream.com/EarlyHistoryOfSmalltalk/)
- Kay, A. C. (1998, 10 October). Re: prototypes vs classes was: Re: Sun's HotSpot. squeak-dev mailing list. http://lists.squeakfoundation.org/pipermail/squeak-dev/1998-October/017019.html
- King, A. (2019, 5 November). Parse, don't validate. https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/
- Liskov, B. H., & Wing, J. M. (1994). A behavioral notion of subtyping. *ACM TOPLAS* 16(6), 1811–1841. https://doi.org/10.1145/197320.197383 (PDF: https://www.cs.columbia.edu/~wing/publications/LiskovWing94.pdf)
- Martin-Löf, P. (1984). *Intuitionistic Type Theory* (notes by G. Sambin). Bibliopolis, Naples.
- Minsky, Y. (2011, 9 March). Effective ML revisited. Jane Street Tech Blog. https://blog.janestreet.com/effective-ml-revisited/
- Reynolds, J. C. (1984). Polymorphism is not set-theoretic. In Kahn, MacQueen & Plotkin (eds.), *Semantics of Data Types*, LNCS 173, 145–156. https://doi.org/10.1007/3-540-13346-1_7
- Russell, B. (1908). Mathematical logic as based on the theory of types. *American Journal of Mathematics* 30(3), 222–262. https://doi.org/10.2307/2369948
- Strom, R. E., & Yemini, S. (1986). Typestate: a programming language concept for enhancing software reliability. *IEEE TSE* SE-12(1), 157–171. https://doi.org/10.1109/TSE.1986.6312929
- TypeScript Handbook. Narrowing (`never`, exhaustiveness, type predicates). https://www.typescriptlang.org/docs/handbook/2/narrowing.html
- TypeScript Handbook. TypeScript for functional programmers (unions, intersections). https://www.typescriptlang.org/docs/handbook/typescript-in-5-minutes-func.html
- Vazou, N., Seidel, E. L., Jhala, R., Vytiniotis, D., & Peyton Jones, S. (2014). Refinement types for Haskell. *ICFP '14*, 269–282. https://doi.org/10.1145/2628136.2628161
- Wadler, P. (2015). Propositions as types. *Communications of the ACM* 58(12), 75–84. https://doi.org/10.1145/2699407 (PDF: https://homepages.inf.ed.ac.uk/wadler/papers/propositions-as-types/propositions-as-types.pdf)

### Not verified at a primary source

- The body text of Cardelli & Wegner §3; only the heading was confirmed.
- The wording of Jacobs & Rutten on objects as coalgebras; the PDF text could not be extracted.
- Minsky's remark that the idea predates his phrase.
- A coiner for the ADT-cardinality framing; none was found, so treat it as folklore.
- Some DOIs and page ranges: the Cardelli & Wegner end page (471–522 vs 523), the Russell 1908 pages, the HVK 1998 pages, and the Hewitt PDF path, which came from standard bibliographies. Check them before publishing.
