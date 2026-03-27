Place the on-device MobileSAM ONNX assets in this folder.

Expected filenames:
- mobilesam_encoder.onnx
- mobilesam_decoder.onnx

Current integration assumptions:
- encoder model accepts a single 1x3x1024x1024 float tensor
- decoder model accepts the standard SAM ONNX inputs:
  - image_embeddings
  - point_coords
  - point_labels
  - mask_input
  - has_mask_input
  - orig_im_size
- decoder returns the standard SAM ONNX outputs:
  - masks
  - iou_predictions
  - low_res_masks

The app uses a center-positive prompt plus four negative corner prompts to isolate the main object in the image.
If these model assets are absent, the app silently skips MobileSAM-assisted context and continues with the existing analysis flow.
