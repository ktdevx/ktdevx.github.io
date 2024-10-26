---
title: 【C言語】goto文でメモリ解放の管理を容易にする
date: 2024-09-29T17:02:39+09:00
draft: false
params:
  toc: true
---

開発中、関数内で複数の動的メモリを確保する必要がある状況に直面することがあります。メモリ確保に失敗した場合、それまでに確保したメモリを解放する必要があり、エラー処理が複雑化しがちです。

ここでは、`goto`文を利用してエラー処理をシンプルにし、メモリ解放の管理を容易にする方法を解説します。

## goto文とは

`goto`文は、関数内で指定されたラベルにジャンプするための構文です。以下のような形式で使います。

```c
goto <ラベル名>;
```

ラベル名は関数内の任意の位置に定義でき、`goto`文はそのラベルの位置までジャンプします。コードの流れを複雑にし、可読性や保守性を低下させる可能性があるため、使用は避けられがちです。

しかし、正しく使用することで、プログラムのシンプルさ、可読性、保守性を向上させることができます。

## メモリ解放を伴う複雑なエラー処理

以下は、複数の動的メモリを管理するコードの一例です。

```c
int example(size_t num)
{
    int *p1, *p2, *p3;

    p1 = (int *)malloc(sizeof(int) * num);
    if (p1 == NULL)
    {
        return -1;
    }

    p2 = (int *)malloc(sizeof(int) * num);
    if (p2 == NULL)
    {
        free(p1);
        return -1;
    }

    p3 = (int *)malloc(sizeof(int) * num);
    if (p3 == NULL)
    {
        free(p1);
        free(p2);
        return -1;
    }

    /* p1,p2,p3を使用した処理 */

    free(p1);
    free(p2);
    free(p3);

    return 0;
}
```

このコードは正しく動作しますが、各メモリの確保と解放が個別に行われており、エラーが発生するたびに解放コードを記述する必要があります。これにより、コードが冗長になり、メモリリークのリスクも増大します。

## goto文でメモリ解放をシンプルにする

`goto`文を利用すると、エラー発生時の処理を一箇所に集約でき、メモリ解放をシンプルに管理できます。

```c
int example(size_t num)
{
    int ret = -1;
    int *p1 = NULL, *p2 = NULL, *p3 = NULL;

    p1 = (int *)malloc(sizeof(int) * num);
    if (p1 == NULL)
    {
        goto cleanup;
    }

    p2 = (int *)malloc(sizeof(int) * num);
    if (p2 == NULL)
    {
        goto cleanup;
    }

    p3 = (int *)malloc(sizeof(int) * num);
    if (p3 == NULL)
    {
        goto cleanup;
    }

    /* p1,p2,p3を使用した処理 */

    ret = 0;

cleanup:
    free(p1);
    free(p2);
    free(p3);

    return ret;
}
```

この例では、`goto cleanup`を使ってエラーが発生した場合でも、最後にすべてのメモリを解放できるようになっています。`free`関数は`NULL`を引数にしても問題ないため、この方法でメモリ管理を安全かつ効率的に行えます。

## まとめ

`goto`文は誤用すると可読性や保守性を損なう可能性がありますが、適切に使うことでコードをシンプルに保つことができます。今回はメモリ管理の例を通じてその利点を説明しましたが、他の状況でも有効な場合があります。**適切な場面で活用することが重要です。**
