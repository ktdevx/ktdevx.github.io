---
title: How to Allocate Dynamic Memory in C and Points of Caution
date: 2024-09-29T17:54:41+09:00
draft: false
tags:
  - C
params:
  toc: true
---

In C, it is possible to allocate memory dynamically. Dynamic memory allocation is useful when the required memory size changes at runtime or when large memory areas are needed.

This article explains how to allocate memory dynamically and provides some points of caution.

## Functions for Dynamic Memory Allocation and Deallocation

The C standard library provides functions for dynamic memory allocation and deallocation.

```c
#include <stdlib.h>

void *malloc(size_t size);
void free(void *ptr);
void *calloc(size_t nmemb, size_t size);
void *realloc(void *ptr, size_t size);
```

To use these functions, include `stdlib.h`.

## Allocate Memory Dynamically

Use the `malloc` function to allocate memory dynamically.

```c
void *malloc(size_t size);
```

The `malloc` function takes the required memory size in bytes as an argument. If the allocation is successful, it returns the address of the allocated memory. If it fails, it returns `NULL`.

For example, to allocate an array of 10 `int` elements, write:

```c
int *ptr;
ptr = (int *)malloc(sizeof(int) * 10);
```

In this example, we use the `sizeof` operator to get the size of an `int` type, multiply it by 10, and pass that value to `malloc`. This allocates memory for 10 `int` elements and stores the starting address in the pointer variable `ptr`.

You can then use the allocated memory through ptr just like a regular array.

## Free Allocated Memory

Dynamically allocated memory must be freed after use to avoid memory leaks, which can exhaust the system’s memory. Use the `free` function to deallocate memory.

```c
void free(void *ptr);
```

The `free` function takes the starting address of the allocated memory as an argument.

```c
free(ptr);
```

This releases the dynamically allocated memory.

## Allocate Initialized Memory

The `calloc` function allows you to allocate memory that is initialized to zero.

```c
void *calloc(size_t nmemb, size_t size);
```

The arguments differ from `malloc`, but the basic concept is the same.

Specify the element size with `size` and the number of elements with `nmemb`. If the allocation is successful, the function returns the address of the allocated memory; otherwise, it returns `NULL`.

```c
int *ptr;
ptr = (int *)calloc(10, sizeof(int));
```

In this example, the element size is specified as the size of `int`, and the number of elements is set to 10. This allocates memory for 10 `int` elements and initializes them to zero.

## Reallocate Memory

The `realloc` function allows you to change the size of memory allocated by `malloc` or `calloc`.

```c
void *realloc(void *ptr, size_t size);
```

The `realloc` function changes the size of the memory pointed to by `ptr` to the size specified by `size`. If successful, it returns the address of the resized memory. If it fails, it returns `NULL`.

```c
int *new_ptr;
new_ptr = (int *)realloc(ptr, sizeof(int) * 20);
```

In this example, we pass the starting address of memory allocated by `malloc` or `calloc` and specify `sizeof(int) * 20` as the new size. The resized memory block is assigned to `new_ptr`.

## Points of Caution for Dynamic Memory Allocation

Here are some important points to consider when using dynamic memory allocation.

### Check the Result of Memory Allocation

Dynamic memory allocation can fail, so always check the return value.

If memory allocation fails, the function returns `NULL`. Dereferencing a `NULL` pointer results in undefined behavior, so be sure to check the function’s return value.

```c
int *ptr;
ptr = (int *)malloc(sizeof(int) * 10);
if (ptr == NULL)
{
    /* Error handling */
}
```

This example uses `malloc`, but the same check is needed for `calloc` and `realloc` as well.

### Use a Separate Pointer Variable to Handle realloc's Return Value

If memory cannot be reallocated, the `realloc` function returns `NULL`. Assigning the return value of `realloc` directly to the same pointer variable used as the input can overwrite the original pointer with `NULL`, potentially causing memory leaks.

To avoid this, use a temporary pointer variable and update the original pointer only if the allocation succeeds.

```c
int *tmp;
tmp = (int *)realloc(ptr, sizeof(int) * 20);
if (tmp == NULL)
{
    /* Error handling */
}
else
{
    ptr = tmp; /* Update if successful */
}
```

This way, the original pointer variable `ptr` is not overwritten if `realloc` fails.

### Free Unneeded Memory

Memory allocated by `malloc` must always be freed with `free`. Failure to do so can result in memory leaks, which may exhaust system memory.

Ensure that every allocation has a matching deallocation within a function to easily verify memory management and reduce the risk of memory leaks.

### Avoid Double Freeing Memory

Freeing dynamically allocated memory twice can lead to undefined behavior.

Double freeing memory can cause instability in other parts of the program that use the released memory, potentially crashing the program. To prevent this, assign `NULL` to the pointer after freeing it.

```c
free(ptr);
ptr = NULL;
```

By setting the pointer to `NULL` after freeing it, you can avoid accidental double freeing.
