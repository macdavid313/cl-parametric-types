;; -*- lisp -*-

;; This file is part of cl-parametric-types.
;; Copyright (c) 2016 Massimiliano Ghilardi
;;
;; This library is free software: you can redistribute it and/or
;; modify it under the terms of the Lisp Lesser General Public License
;; (http://opensource.franz.com/preamble.html), known as the LLGPL.
;;
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty
;; of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;; See the Lisp Lesser General Public License for more details.

#|
Functions to normalize types, i.e. to replace:
  BIT               -> (INTEGER 0 1)
  FIXNUM            -> (INTEGER MOST-NEGATIVE-FIXNUM MOST-POSITIVE-FIXNUM)
  SIGNED-BYTE       -> (INTEGER * *)
  UNSIGNED-BYTE     -> (INTEGER 0 *)
  (SIGNED-BYTE N)   -> (INTEGER (LOGNOT (ASH 1 (1- N))) (ASH 1 (1- N)))
  (UNSIGNED-BYTE N) -> (INTEGER 0 (ASH 1 N))
  INTEGER           -> (INTEGER * *)
  (INTEGER N)       -> (INTEGER N *)
  SINGLE-FLOAT      -> (SINGLE-FLOAT * *)
  (SINGLE-FLOAT N)  -> (SINGLE-FLOAT N *)
  DOUBLE-FLOAT      -> (DOUBLE-FLOAT * *)
  (DOUBLE-FLOAT N)  -> (DOUBLE-FLOAT N *)
  array-type        -> (array-type * *)
  string-type       -> (string-type *)
  BOOLEAN           -> (MEMBER T NIL)
|#

(in-package #:cl-parametric-types)

(declaim (ftype (function ((or symbol cons)) (values (or symbol cons) &optional)) normalize-type))

(defun normalize-type-unsigned-byte (type)
  (declare (type cons type))
  (let ((bits (or (second type) '*)))
    (if (eq '* bits)
        '(integer 0 *)
        `(integer 0 ,(ash 1 bits)))))

(defun normalize-type-signed-byte (type)
  (declare (type cons type))
  (let ((bits (or (second type) '*)))
    (if (eq '* bits)
        '(integer * *)
        (let ((n-max (ash 1 (1- bits))))
          `(integer ,(lognot n-max) ,n-max)))))

(defun normalize-type-real (type)
  (declare (type cons type))
  (let ((first (first type))
        (lo (or (second type) '*))
        (hi (or (third  type) '*)))
    `(,first ,lo ,hi)))

(defun normalize-type-array (type)
  (declare (type cons type))
  (let ((array-type   (first type))
        (element-type (or (normalize-type (second type)) '*))
        (dimensions   (or (third type) '*)))
    (list array-type element-type dimensions)))

(defun normalize-type (type)
  (declare (type (or symbol cons) type))
  (etypecase type
    (symbol
     (case type
       (bit                         '(integer 0 1))
       (fixnum                      '(integer #.most-negative-fixnum #.most-positive-fixnum))
       (unsigned-byte               '(integer 0 *))
       ((signed-byte  integer)      '(integer * *))
       ((single-float double-float) `(type * *))
       ((string simple-string simple-base-string vector simple-vector bit-vector simple-bit-vector)
        `(,type *))
       ((array simple-array) `(,type * *))
       (boolean                     '(member t nil))
       (otherwise     type)))
    (cons
     (case (first type)
       (signed-byte   (normalize-type-signed-byte   type))
       (unsigned-byte (normalize-type-unsigned-byte type))
       ((integer single-float double-float)        (normalize-type-real type))
       ((array        simple-array  vector)        (normalize-type-array type))
       (member        type)
       (otherwise     (cons (first type)
                            (loop :for e :in (rest type)
                               :collect (normalize-type e))))))))

(defun normalize-typexpand-list (types)
  (declare (type list types))
   (loop :for type :in types
      :collect (normalize-type (typexpand type))))
