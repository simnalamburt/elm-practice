Elm Effect Manager Practice
========
[Effect Manager]에 대한 이해를 돕기위해 만든 리포지터리.

```bash
elm-reactor

# See http://127.0.0.1:8000/src/App.elm
```

Effect Manager란?
--------
Elm은 하스켈처럼, 모든 함수가 퓨어한 언어이다. 그래서 사이드이펙트를 가진
라이브러리를 만들으려면, 평범한 방법으로는 안된다. 모듈 선언도 `effect module`
이런식으로 특이하게 해야한다. 이를 Elm 커뮤니티에선 [Effect Manager]라고 부른다.

```elm
effect module MyRandom where { command = MyCmd, subscription = MySub }
  exposing (
    ...
```

문제는 [Effect Manager] 만드는법이 어디에도 설명이 안되어있다는 점이다. elmlang
슬랙에 물어보아도, 대부분 "최대한 만들지 마라"라고만 설명할뿐 [Effect Manager]
만드는 방법을 알고있는 사람들도 많지 않고, 좋은 튜토리얼도 없다. 공식문서에선
이미 만들어져있는 라이브러리들 안의 [Effect Manager]들을 보고 따라 만들라는데,
대부분 코드가 너무 복잡해서 한눈에 보고 이해할 수 없다.

그래서 표준 라이브러리의 [`Random.elm`]를 고쳐서, 한눈에 보고 이해할 수 있는
간단한 형태로 바꾸었다. 주석에 최대한 자세하게 설명을 달아두었으니, 다른
개발자가 보고 이해할 수 있었으면 좋겠다.

봐야할것
--------
1.  [`MyRandom.elm`][code]
2.  [`Platform` 모듈의 Effect Manager Helpers][helper]
3.  [`Task` 모듈의 Commands 관련 함수들](http://package.elm-lang.org/packages/elm-lang/core/latest/Task#commands)

--------

`elm-practice` is primarily distributed under the terms of both the [MIT
license] and the [Apache License (Version 2.0)]. See [COPYRIGHT] for details.

[Effect Manager]: https://guide.elm-lang.org/effect_managers/
[`Random.elm`]: https://github.com/elm-lang/core/blob/master/src/Random.elm
[code]: https://github.com/simnalamburt/elm-practice/blob/master/src/MyRandom.elm
[helper]: http://package.elm-lang.org/packages/elm-lang/core/5.0.0/Platform#effect-manager-helpers
[MIT license]: LICENSE-MIT
[Apache License (Version 2.0)]: LICENSE-APACHE
[COPYRIGHT]: COPYRIGHT
