; ModuleID = 'ex04.c'
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Function Attrs: nounwind uwtable
define i32 @main() #0 {
  %1 = alloca i32, align 4
  %ia = alloca i32, align 4
  %ib = alloca i32, align 4
  %ic = alloca i32, align 4
  store i32 0, i32* %1, align 4
  store i32 1, i32* %ia, align 4
  store i32 2, i32* %ib, align 4
  store i32 2, i32* %ic, align 4
  %2 = load i32, i32* %ia, align 4
  %3 = load i32, i32* %ib, align 4
  %4 = icmp sgt i32 %2, %3
  br i1 %4, label %5, label %6

; <label>:5                                       ; preds = %0
  store i32 1, i32* %1, align 4
  br label %7

; <label>:6                                       ; preds = %0
  store i32 0, i32* %1, align 4
  br label %7

; <label>:7                                       ; preds = %6, %5
  %8 = load i32, i32* %1, align 4
  ret i32 %8
}

; Function Attrs: nounwind uwtable
define double @dMain() #0 {
  %da = alloca double, align 8
  %db = alloca double, align 8
  %dSum = alloca double, align 8
  %dDif = alloca double, align 8
  %dMul = alloca double, align 8
  %dDiv = alloca double, align 8
  store double 1.000000e+00, double* %da, align 8
  store double 2.000000e+00, double* %db, align 8
  %1 = load double, double* %da, align 8
  %2 = load double, double* %db, align 8
  %3 = fadd double %1, %2
  store double %3, double* %dSum, align 8
  %4 = load double, double* %da, align 8
  %5 = load double, double* %db, align 8
  %6 = fsub double %4, %5
  store double %6, double* %dDif, align 8
  %7 = load double, double* %da, align 8
  %8 = load double, double* %db, align 8
  %9 = fmul double %7, %8
  store double %9, double* %dMul, align 8
  %10 = load double, double* %da, align 8
  %11 = load double, double* %db, align 8
  %12 = fdiv double %10, %11
  store double %12, double* %dDiv, align 8
  %13 = load double, double* %dSum, align 8
  ret double %13
}

attributes #0 = { nounwind uwtable "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.ident = !{!0}

!0 = !{!"clang version 3.8.0 (tags/RELEASE_380/final)"}
