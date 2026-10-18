# MCP tool schemas use explicit `property` blocks (the real schema, per
# `tofu providers schema -json`, has no top-level properties_json shortcut -
# that shortcut only exists 2+ levels deep for nested array items).
# `credential_provider_configuration.gateway_iam_role {}` means the Gateway
# invokes the Lambda using its own execution role's identity (gateway.tf's
# gateway_exec) - no separate credential provider needed for this call path.

resource "aws_bedrockagentcore_gateway_target" "list_products" {
  gateway_identifier = aws_bedrockagentcore_gateway.tools.gateway_id
  name               = "list-products"
  description        = "List available products, optionally filtered by category."

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.list_products.arn

        tool_schema {
          inline_payload {
            name        = "list_products"
            description = "List available products. Pass category to filter (optional)."

            input_schema {
              type = "object"

              property {
                name        = "category"
                type        = "string"
                description = "Optional substring filter on the product name"
                required    = false
              }
            }
          }
        }
      }
    }
  }

  credential_provider_configuration {
    gateway_iam_role {}
  }
}

resource "aws_bedrockagentcore_gateway_target" "get_order_status" {
  gateway_identifier = aws_bedrockagentcore_gateway.tools.gateway_id
  name               = "get-order-status"
  description        = "Look up an order's status by ID."

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.get_order_status.arn

        tool_schema {
          inline_payload {
            name        = "get_order_status"
            description = "Look up an order's status. order_id is required, e.g. ORD-1001."

            input_schema {
              type = "object"

              property {
                name        = "order_id"
                type        = "string"
                description = "Order ID to look up, e.g. ORD-1001"
                required    = true
              }
            }
          }
        }
      }
    }
  }

  credential_provider_configuration {
    gateway_iam_role {}
  }
}
