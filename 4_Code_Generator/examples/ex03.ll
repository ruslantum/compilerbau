; ModuleID = '../examples/ex03.c'
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.11.0"

; Function Attrs: nounwind ssp uwtable
define i32 @returnSomething() #0 {
  %something = alloca i32, align 4
  store i32 1, i32* %something, align 4
  %1 = load i32, i32* %something, align 4
  ret i32 %1
}

; Function Attrs: nounwind ssp uwtable
define void @doSomething() #0 {
  %something = alloca i32, align 4
  %1 = call i32 @returnSomething()
  store i32 %1, i32* %something, align 4
  ret void
}

attributes #0 = { nounwind ssp uwtable "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="core2" "target-features"="+cx16,+fxsr,+mmx,+sse,+sse2,+sse3,+ssse3" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"PIC Level", i32 2}
!1 = !{!"Apple LLVM version 7.3.0 (clang-703.0.31)"}
