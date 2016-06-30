; ModuleID = 'ex08.c'
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Function Attrs: nounwind uwtable
define double @foo() #0 {
  %a = alloca double, align 8
  store double 7.098000e-07, double* %a, align 8
  %1 = load double, double* %a, align 8
  ret double %1
}

; Function Attrs: nounwind uwtable
define i32 @main() #0 {
  %1 = alloca i32, align 4
  %i = alloca double, align 8
  %counter = alloca i32, align 4
  %bla = alloca double, align 8
  store i32 0, i32* %1, align 4
  store double 2.098000e-07, double* %i, align 8
  store i32 0, i32* %counter, align 4
  br label %2

; <label>:2                                       ; preds = %5, %0
  %3 = load i32, i32* %counter, align 4
  %4 = icmp slt i32 %3, 10
  br i1 %4, label %5, label %11

; <label>:5                                       ; preds = %2
  %6 = load double, double* %i, align 8
  %7 = call double @foo()
  %8 = fadd double %6, %7
  store double %8, double* %bla, align 8
  %9 = load i32, i32* %counter, align 4
  %10 = add nsw i32 %9, 1
  store i32 %10, i32* %counter, align 4
  br label %2

; <label>:11                                      ; preds = %2
  ret i32 0
}

attributes #0 = { nounwind uwtable "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.ident = !{!0}

!0 = !{!"clang version 3.8.0 (tags/RELEASE_380/final)"}
