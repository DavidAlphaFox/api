(in-package :turtl)

(defroute (:post "/api/filez" :chunk t) (req res)
  (catch-errors (res)
    (with-chunking req (data lastp)
      (format t "chunk: ~a~%" (length data))
      (when lastp
        (send-response res :body "thxLOL")))))

(defroute (:post "/api/files") (req res)
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (file (make-file :uploading t))
            (upload-path (format nil "/files/~a/~a" user-id (gethash "id" file)))
            (upload-id (s3-upload-init path)))
      (setf (gethash "upload_id" file) upload-id)
      (wait-for (save-file user-id file)
        (send-json upload-id)))))

(defroute (:post "/api/files_" :chunk t) (req res)
  (catch-errors (res)
    (let ((s3-uploader nil)
          (user-id (user-id req))
          (saved (make-array 0 :element-type '(unsigned-byte 8)))
          (file (make-file)))
      (format t "- setting up chunking.~%")
      (with-chunking req (chunk-data last-chunk-p)
        (unless s3-uploader
          (setf s3-uploader :starting)
          (let ((path (format nil "/files/~a/~a" user-id (gethash "id" file))))
            (format t "- starting uploader with path: ~a~%" path)
            (alet ((uploader (s3-upload path)))
              (format t "- uploader created.~%")
              (setf s3-uploader uploader))))
        (if (eq s3-uploader :starting)
            (format t "- buffering data until uploader ready: ~a~%" (length saved))
            (format t "- uploader ready, passing in data: ~a~%" (length chunk-data)))
        (if (eq s3-uploader :starting)
            (setf saved (cl-async-util:append-array saved chunk-data))
            (let ((chunk-data (if saved
                                  (prog1
                                    (cl-async-util:append-array saved chunk-data)
                                    (setf saved nil))
                                  chunk-data)))
              (funcall s3-uploader chunk-data (not last-chunk-p))))))))

