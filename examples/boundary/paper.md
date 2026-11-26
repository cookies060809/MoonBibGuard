# 边界示例：嵌套花括号、引号字段、代码块、行内代码

嵌套花括号的标题 [@nested2021] 应被原样保留。

引号包裹字段的条目 [@quoted2019]。

年份用裸值书写的条目 [@bare2023]。

只有年份的引用（连接符形式）[--@nested2021]。

带定位信息的多引用 [@quoted2019, p. 42; @bare2023]。

代码块里的内容不检查：

```python
# [@fake_key_in_code]
print("hello")
```

行内代码也不检查：`[@fake_inline]`。

邮箱地址 someone@example.com 不是引用。
